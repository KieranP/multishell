import Foundation
import MultishellCore
import MultishellGitKit

// MARK: - Projects

extension AppModel {
  public func chooseProject() async {
    guard let url = await platform.chooseDirectory(prompt: "Add Project") else { return }
    await addProject(at: url)
  }

  public func addProject(at url: URL) async {
    guard let worktrees else { return }
    guard await worktrees.isRepository(url) else {
      presentedError = .notARepository(url)
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
  public func requestProjectRemoval(_ project: Project, from source: PendingProjectRemoval.Source) {
    pendingProjectRemoval = PendingProjectRemoval(project: project, source: source)
  }

  /// What the confirmation says, with the live terminal count.
  public func projectRemovalMessage(for project: Project) -> String {
    let live = workspace.worktrees(of: project.id).map { liveTerminalCount(in: $0.id) }
    return PendingProjectRemoval.message(liveTerminals: live.reduce(0, +))
  }

  public func removeProject(_ project: Project) {
    commonGitDirectories[project.id] = nil
    worktreeRecords[project.id] = nil
    store.removeProject(project.id)
    sync()
    Task { await rearmWatcher() }
  }

  /// Moves `id` to sit just above or just below `target`.
  public func moveProject(_ id: Project.ID, _ placement: ProjectPlacement, _ target: Project.ID) {
    let projects = workspace.projects
    guard
      let from = projects.firstIndex(where: { $0.id == id }),
      let anchor = projects.firstIndex(where: { $0.id == target }),
      from != anchor
    else { return }
    let destination = placement == .above ? anchor : anchor + 1
    store.moveProjects(from: IndexSet(integer: from), to: destination)
  }

  public func setExpanded(_ expanded: Bool, for project: Project) {
    store.setExpanded(expanded, forProject: project.id)
  }

  public func updateSettings(_ settings: ProjectSettings, for project: Project) {
    store.updateSettings(settings, forProject: project.id)
  }

  /// Refresh chosen by the user. A failure already shown for this project is
  /// shown again: the click asked for an answer.
  public func refreshRequested(_ project: Project) async {
    missingProjects.remove(project.id)
    await refresh(project)
  }

  public func refresh(_ project: Project) async {
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
  public func select(_ worktree: Worktree, openingFirstTab: Bool = true) -> Bool {
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
  public func isBusy(_ id: Worktree.ID) -> Bool {
    worktreeOperations.isBusy(id)
  }

  /// The pane's Dismiss after a failed stage. A dismissed post-create
  /// failure hands over the way a finished hook does: the first tab opens.
  public func dismissOperationFailure(of worktree: Worktree) {
    guard let operation = worktreeOperations.dismiss(worktree.id) else { return }
    if operation.step == .postCreateHook, workspace.selectedWorktreeID == worktree.id,
      let current = workspace.worktree(worktree.id)
    {
      select(current)
    }
  }

  /// Checked before anything that starts a shell: selecting, a new tab, a
  /// split. A missing directory is refused, not worked around.
  public func directoryExists(of worktree: Worktree) -> Bool {
    if FileManager.default.fileExists(atPath: worktree.path.path) { return true }
    presentedError = .worktreeDirectoryMissing(worktree.path.path)
    return false
  }

  /// Opens the sheet for `project`, or for the project the workspace is
  /// working in when none is given: the selected worktree's, or the only one.
  /// With several projects and nothing selected the picker starts blank.
  public func requestNewWorktree(in project: Project? = nil) {
    newWorktreeRequest = NewWorktreeRequest(projectID: (project ?? activeProject)?.id)
  }

  public func plannedPath(
    forBranch branch: String, createBranch: Bool, in project: Project
  )
    -> URL?
  {
    worktrees?.plannedPath(
      forBranch: branch, createBranch: createBranch, in: project,
      settings: workspace.worktreeSettings(for: project))
  }

  public func hasCommits(_ project: Project) async -> Bool {
    await worktrees?.hasCommits(project) ?? false
  }

  public func branches(of project: Project) async -> (local: [String], remote: [String]) {
    (
      (try? await worktrees?.localBranches(project)) ?? [],
      (try? await worktrees?.remoteBranches(project)) ?? []
    )
  }

  public func currentBranch(of project: Project) async -> String {
    (try? await worktrees?.currentBranch(project)) ?? "HEAD"
  }

  /// Returns once the worktree exists and is selected, or the create
  /// failed. The post-create hook then runs on its own with the pane
  /// showing it, and holds the first tab back until it ends; see
  /// `WorktreeOperation`.
  public func createWorktree(
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
      worktreeOperations.begin(.postCreateHook, on: created.id)
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
      // there to have a pane and the hook still owns it; an alert otherwise.
      let shownInPane =
        workspace.worktree(worktree.id) != nil
        && worktreeOperations.fail(
          .postCreateHook, on: worktree.id, message: PresentedError(error).message)
      if !shownInPane { report(error) }
      return
    }
    // A removal that began meanwhile owns the entry now.
    guard worktreeOperations.finish(.postCreateHook, on: worktree.id) else { return }
    // The first tab was held back while the hook ran; it opens now if the
    // worktree is still what the user is looking at, else on the next visit.
    if workspace.selectedWorktreeID == worktree.id, let current = workspace.worktree(worktree.id) {
      select(current)
    }
  }

  public func setConfirmsWorktreeRemoval(_ enabled: Bool) {
    store.setConfirmsWorktreeRemoval(enabled)
  }

  public func setDeletesBranchWithWorktree(_ enabled: Bool) {
    store.setDeletesBranchWithWorktree(enabled)
  }

  /// Entry point from the UI. Asks first unless the settings have settled
  /// both the removal and the branch; see `PendingWorktreeRemoval.decide`.
  /// Nothing while a create or remove is already running there.
  public func requestRemoval(of worktree: Worktree) {
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
  public func removalWarning(for worktree: Worktree) -> String? {
    PendingWorktreeRemoval.warning(
      changedFiles: statuses[worktree.id]?.changedFiles ?? 0,
      liveTerminals: liveTerminalCount(in: worktree.id))
  }

  /// The pane shows each stage while this runs. What a failed stage does to
  /// the pane and the alert is `RemovalFailure`'s decision; this attaches
  /// the retry it names and puts the worktree back if it is still there.
  public func removeWorktree(
    _ worktree: Worktree, force: Bool = false, deletingBranch: Bool = false
  ) async {
    guard let worktrees, let project = workspace.project(worktree.projectID) else { return }
    worktreeOperations.begin(.init(WorktreeRemovalStep.first(for: project)), on: worktree.id)
    do {
      try await worktrees.remove(
        worktree, force: force, deletingBranch: deletingBranch, in: project,
        shellPath: workspace.defaultShell(for: project),
        onStep: { [weak self] step in
          Task { @MainActor in self?.worktreeOperations.advance(to: .init(step), on: worktree.id) }
        })
    } catch {
      let failure = RemovalFailure.describe(
        error, deletingBranch: deletingBranch ? worktree.branch : nil, force: force)
      switch failure {
      case .vetoed(let message):
        if !worktreeOperations.fail(.preDeleteHook, on: worktree.id, message: message) {
          report(error)
        }
        return
      case .alert(let title, let message, let retry, let worktreeRemoved):
        var presented = PresentedError(title: title, message: message)
        switch retry {
        case .removeAnyway:
          presented.retryLabel = "Remove Anyway"
          presented.retry = { [weak self] in
            await self?.removeWorktree(worktree, force: true, deletingBranch: deletingBranch)
          }
        case .deleteBranchAnyway(let branch):
          presented.retryLabel = "Delete Branch Anyway"
          presented.retry = { [weak self] in
            await self?.deleteBranch(branch, of: project, force: true)
          }
        case nil:
          break
        }
        presentedError = presented
        guard worktreeRemoved else {
          worktreeOperations.clear(worktree.id)
          return
        }
      }
    }
    worktreeOperations.clear(worktree.id)
    await refresh(project)
    await rearmWatcher()
    sync()
  }

  /// The branch alone, after a removal that left it behind.
  public func deleteBranch(_ branch: String, of project: Project, force: Bool) async {
    guard let worktrees else { return }
    do {
      try await worktrees.deleteBranch(branch, force: force, in: project)
    } catch {
      report(error)
    }
  }
}
