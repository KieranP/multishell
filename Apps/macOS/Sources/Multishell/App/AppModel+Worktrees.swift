import AppKit
import MultishellCore
import MultishellGitKit
import SwiftUI

// MARK: - Projects

extension AppModel {
  func chooseProject() async {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.prompt = "Add Project"

    guard panel.runModal() == .OK, let url = panel.url else { return }
    await addProject(at: url)
  }

  func addProject(at url: URL) async {
    guard let worktrees else { return }
    guard await worktrees.isRepository(url) else {
      presentedError = PresentedError(
        title: "Not a git repository",
        message: "\(url.lastPathComponent) has no .git directory, or git could not read it."
      )
      return
    }
    // A subdirectory or a linked worktree is the same repository; adding it
    // as its own project would list the same worktrees twice.
    let root = (try? await worktrees.repositoryRoot(containing: url)) ?? url
    let project = store.addProject(at: root)
    await refresh(project)
    await rearmWatcher()
  }

  /// Entry point from the UI. Always asks: removal closes every live
  /// terminal in the project's worktrees, with no undo.
  func requestProjectRemoval(_ project: Project, from source: PendingProjectRemoval.Source) {
    pendingProjectRemoval = PendingProjectRemoval(project: project, source: source)
  }

  /// What the confirmation says, with the live terminal count.
  func projectRemovalMessage(for project: Project) -> String {
    let live = workspace.worktrees(of: project.id).map { liveTerminalCount(in: $0.id) }
    return PendingProjectRemoval.message(liveTerminals: live.reduce(0, +))
  }

  func removeProject(_ project: Project) {
    commonGitDirectories[project.id] = nil
    worktreeRecords[project.id] = nil
    store.removeProject(project.id)
    sync()
    Task { await rearmWatcher() }
  }

  /// Moves `id` to sit just above or just below `target`.
  func moveProject(_ id: Project.ID, _ edge: VerticalEdge, _ target: Project.ID) {
    let projects = workspace.projects
    guard
      let from = projects.firstIndex(where: { $0.id == id }),
      let anchor = projects.firstIndex(where: { $0.id == target }),
      from != anchor
    else { return }
    let destination = edge == .top ? anchor : anchor + 1
    store.moveProjects(from: IndexSet(integer: from), to: destination)
  }

  func setExpanded(_ expanded: Bool, for project: Project) {
    store.setExpanded(expanded, forProject: project.id)
  }

  func updateSettings(_ settings: ProjectSettings, for project: Project) {
    store.updateSettings(settings, forProject: project.id)
  }

  /// Refresh chosen by the user. A failure already shown for this project is
  /// shown again: the click asked for an answer.
  func refreshRequested(_ project: Project) async {
    missingProjects.remove(project.id)
    await refresh(project)
  }

  func refresh(_ project: Project) async {
    guard let worktrees else { return }
    let path = project.path.path
    guard await Self.offMain({ FileManager.default.fileExists(atPath: path) }) else {
      missingProjects.insert(project.id)
      return
    }
    // Read before the list so a change landing in between is caught by the
    // next tick rather than lost.
    var records: WorktreeRecords?
    if let common = await commonGitDirectory(of: project) {
      records = await Self.offMain { WorktreeRecords.read(commonDirectory: common) }
    }
    do {
      let discovered = try await worktrees.refresh(project)
      // Removed while git ran: the store ignores the list, and the records
      // and directory cached above must not come back for it either.
      guard workspace.project(project.id) != nil else {
        commonGitDirectories[project.id] = nil
        return
      }
      store.replaceWorktrees(discovered, forProject: project.id)
      worktreeRecords[project.id] = records
      missingProjects.remove(project.id)
    } catch {
      // Every watcher tick and every return to the foreground refreshes a
      // project git cannot read, so the alert goes up on the first failure
      // only; the row stays dimmed until a refresh succeeds.
      if missingProjects.insert(project.id).inserted { report(error) }
    }
  }
}

// MARK: - Worktrees

extension AppModel {
  /// A worktree with no tabs gets one, unless the setting says selecting
  /// should only show the worktree and leave the first shell to Cmd+T or
  /// the actions menu. `openingFirstTab: false` is for a caller about to
  /// open its own tab. Returns false when the directory is gone and nothing
  /// was selected, so that caller does not act on whatever was selected.
  @discardableResult
  func select(_ worktree: Worktree, openingFirstTab: Bool = true) -> Bool {
    guard directoryExists(of: worktree) else { return false }
    store.selectWorktree(worktree.id)
    warmWorktrees.insert(worktree.id)
    if openingFirstTab, !isBusy(worktree.id), workspace.tabs(in: worktree.id).isEmpty,
      workspace.opensTerminalOnSelect
    {
      openFirstOrNewTab(in: worktree)
    }
    sync()
    return true
  }

  /// A create or remove is running on the worktree, or has failed and not
  /// been dismissed. Nothing starts a shell there until then: a post-create
  /// hook is still installing, the worktree is about to go, or the pane is
  /// saying what went wrong.
  func isBusy(_ id: Worktree.ID) -> Bool {
    worktreeOperations[id] != nil
  }

  /// The pane's Dismiss after a failed stage. A dismissed post-create
  /// failure hands over the way a finished hook does: the first tab opens.
  func dismissOperationFailure(of worktree: Worktree) {
    guard let operation = worktreeOperations[worktree.id], !operation.isRunning else { return }
    worktreeOperations[worktree.id] = nil
    if operation.step == .postCreateHook, workspace.selectedWorktreeID == worktree.id,
      let current = workspace.worktree(worktree.id)
    {
      select(current)
    }
  }

  /// A shell spawned in a missing directory silently lands in $HOME, which
  /// is worse than an honest refusal. Checked before anything that starts a
  /// shell: selecting, a new tab, a split.
  func directoryExists(of worktree: Worktree) -> Bool {
    if FileManager.default.fileExists(atPath: worktree.path.path) { return true }
    presentedError = PresentedError(
      title: "Worktree directory is missing",
      message:
        "\(worktree.path.path) does not exist. If it was deleted by hand, remove the worktree to let git prune it."
    )
    return false
  }

  /// Opens the sheet for `project`, or for the project the workspace is
  /// working in when none is given: the selected worktree's, or the only one.
  /// With several projects and nothing selected the picker starts blank.
  func requestNewWorktree(in project: Project? = nil) {
    newWorktreeRequest = NewWorktreeRequest(projectID: (project ?? activeProject)?.id)
  }

  func plannedPath(forBranch branch: String, createBranch: Bool, in project: Project) -> URL? {
    worktrees?.plannedPath(
      forBranch: branch, createBranch: createBranch, in: project,
      settings: workspace.worktreeSettings(for: project))
  }

  func hasCommits(_ project: Project) async -> Bool {
    await worktrees?.hasCommits(project) ?? false
  }

  func branches(of project: Project) async -> (local: [String], remote: [String]) {
    (
      (try? await worktrees?.localBranches(project)) ?? [],
      (try? await worktrees?.remoteBranches(project)) ?? []
    )
  }

  func currentBranch(of project: Project) async -> String {
    (try? await worktrees?.currentBranch(project)) ?? "HEAD"
  }

  /// Returns once the worktree exists and is selected, or the create
  /// failed. The post-create hook then runs on its own with the pane
  /// showing it, and holds the first tab back until it ends; see
  /// `WorktreeOperation`.
  func createWorktree(
    branch: String,
    basedOn startPoint: String?,
    createBranch: Bool,
    in project: Project
  ) async {
    guard let worktrees else { return }
    defer { worktreeCreationStep = nil }
    let settings = workspace.worktreeSettings(for: project)
    let shell = workspace.defaultShell(for: project)
    let path: URL
    do {
      path = try await worktrees.add(
        branch: branch,
        basedOn: startPoint,
        createBranch: createBranch,
        in: project,
        settings: settings,
        shellPath: shell,
        onStep: { [weak self] step in Task { @MainActor in self?.worktreeCreationStep = step } }
      )
    } catch {
      report(error)
      return
    }
    await refresh(project)
    await rearmWatcher()
    // git reports resolved paths, so on a symlinked volume the directory we
    // asked for and the one it lists can differ. Fall back to the branch.
    let name = WorktreeCoordinator.branchName(
      branch, createBranch: createBranch, settings: settings)
    guard
      let created = workspace.worktree(path.standardizedFileURL.path)
        ?? workspace.worktrees(of: project.id).first(where: { $0.branch == name })
    else { return }
    if WorktreeHooks.hasScript(project.settings.postCreateHook) {
      worktreeOperations[created.id] = WorktreeOperation(.postCreateHook)
      postCreateHooks[created.id] = Task {
        await runPostCreateHook(for: created, branch: name, in: project, shellPath: shell)
      }
    }
    select(created)
  }

  private func runPostCreateHook(
    for worktree: Worktree, branch: String, in project: Project, shellPath: String?
  ) async {
    defer { postCreateHooks[worktree.id] = nil }
    do {
      try await worktrees?.runPostCreate(
        for: project, worktreePath: worktree.path, branch: branch, shellPath: shellPath)
    } catch {
      // The pane says so until dismissed, where the worktree is still
      // there to have a pane; an alert otherwise.
      if worktreeOperations[worktree.id]?.step == .postCreateHook,
        workspace.worktree(worktree.id) != nil
      {
        worktreeOperations[worktree.id]?.failure = PresentedError(error).message
      } else {
        report(error)
      }
      return
    }
    // A removal that began meanwhile owns the entry now.
    guard worktreeOperations[worktree.id]?.step == .postCreateHook else { return }
    worktreeOperations[worktree.id] = nil
    // The first tab was held back while the hook ran; it opens now if the
    // worktree is still what the user is looking at, else on the next visit.
    if workspace.selectedWorktreeID == worktree.id, let current = workspace.worktree(worktree.id) {
      select(current)
    }
  }

  func setConfirmsWorktreeRemoval(_ enabled: Bool) {
    store.setConfirmsWorktreeRemoval(enabled)
  }

  func setDeletesBranchWithWorktree(_ enabled: Bool) {
    store.setDeletesBranchWithWorktree(enabled)
  }

  /// Entry point from the UI. Asks first unless the settings have settled
  /// both the removal and the branch; see `PendingWorktreeRemoval.decide`.
  /// Nothing while a create or remove is already running there.
  func requestRemoval(of worktree: Worktree) {
    guard !isBusy(worktree.id) else { return }
    switch PendingWorktreeRemoval.decide(
      worktree, confirms: workspace.confirmsWorktreeRemoval,
      alwaysDeletesBranch: workspace.deletesBranchWithWorktree)
    {
    case .ask(let pending):
      pendingRemoval = pending
    case .remove(let deletingBranch):
      Task { await removeWorktree(worktree, deletingBranch: deletingBranch) }
    }
  }

  /// What the confirmation should warn about, beyond the removal itself.
  func removalWarning(for worktree: Worktree) -> String? {
    var notes: [String] = []
    if let status = statuses[worktree.id], status.isDirty {
      notes.append(
        "It has \(status.changedFiles) changed file\(status.changedFiles == 1 ? "" : "s") that will be lost."
      )
    }
    let terminals = liveTerminalCount(in: worktree.id)
    if terminals > 0 {
      notes.append("\(terminals) open terminal\(terminals == 1 ? "" : "s") will be closed.")
    }
    return notes.isEmpty ? nil : notes.joined(separator: " ")
  }

  /// The pane shows each stage while this runs. A git refusal clears it and
  /// the terminals come back, with the alert offering the forced form; a
  /// pre-delete veto leaves the pane saying why until dismissed.
  func removeWorktree(
    _ worktree: Worktree, force: Bool = false, deletingBranch: Bool = false
  ) async {
    guard let worktrees, let project = workspace.project(worktree.projectID) else { return }
    worktreeOperations[worktree.id] = WorktreeOperation(WorktreeRemovalStep.first(for: project))
    do {
      try await worktrees.remove(
        worktree, force: force, deletingBranch: deletingBranch, in: project,
        shellPath: workspace.defaultShell(for: project),
        onStep: { [weak self] step in
          Task { @MainActor in
            guard self?.worktreeOperations[worktree.id]?.isRunning == true else { return }
            self?.worktreeOperations[worktree.id] = WorktreeOperation(step)
          }
        })
    } catch let failure as HookFailure where failure.stage.operationHappened {
      // The branch is deleted after the post hook, so a hook that failed
      // kept it; the alert has to say so, or the user believes it went.
      var presented = PresentedError(failure)
      if deletingBranch, let branch = worktree.branch {
        presented = PresentedError(
          title: presented.title,
          message: presented.message + "\n\nThe branch \(branch) was kept.")
      }
      presentedError = presented
    } catch let failure as HookFailure {
      // The pre-delete hook refused, so nothing was removed and there is
      // nothing to refresh; the worktree keeps its pane to say why.
      worktreeOperations[worktree.id] = WorktreeOperation(
        .preDeleteHook, failure: PresentedError(failure).message)
      return
    } catch let failure as BranchDeletionFailure {
      // The worktree is gone; only the branch stayed, because it has
      // commits nothing else has. Offer the forced form.
      var presented = PresentedError(failure)
      presented.retryLabel = "Delete Branch Anyway"
      presented.retry = { [weak self] in
        await self?.deleteBranch(failure.branch, of: project, force: true)
      }
      presentedError = presented
    } catch {
      // git refuses dirty or locked worktrees. Offer the force form
      // rather than leaving the user to find a terminal.
      var presented = PresentedError(error)
      if !force {
        presented.retryLabel = "Remove Anyway"
        presented.retry = { [weak self] in
          await self?.removeWorktree(worktree, force: true, deletingBranch: deletingBranch)
        }
      }
      presentedError = presented
      worktreeOperations[worktree.id] = nil
      return
    }
    worktreeOperations[worktree.id] = nil
    await refresh(project)
    await rearmWatcher()
    sync()
  }

  /// The branch alone, after a removal that left it behind.
  func deleteBranch(_ branch: String, of project: Project, force: Bool) async {
    guard let worktrees else { return }
    do {
      try await worktrees.deleteBranch(branch, force: force, in: project)
    } catch {
      report(error)
    }
  }
}
