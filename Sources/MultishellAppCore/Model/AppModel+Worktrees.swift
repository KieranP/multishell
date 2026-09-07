import Foundation
import MultishellCore
import MultishellGitKit
import MultishellProcess

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
    forgetMergeStates(of: project.id)
    mergeBases[project.id] = nil
    commonGitDirectories[project.id] = nil
    worktreeRecords[project.id] = nil
    sharedSettings[project.id] = nil
    sharedSettingsStamps[project.id] = nil
    sharedSettingsProblems[project.id] = nil
    if pendingSharedHooksTrust?.projectID == project.id { pendingSharedHooksTrust = nil }
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
    let path = project.path
    guard await Self.offMain({ FileManager.default.fileExists(atPath: path.path) }) else {
      missingProjects.insert(project.id)
      return
    }
    // Read before the list so a change landing in between is caught by the
    // next tick rather than lost.
    var records: WorktreeRecords?
    if let common = await commonGitDirectory(of: project) {
      records = await Self.offMain { WorktreeRecords.read(commonDirectory: common) }
    }
    let shared = await Self.offMain { Self.readSharedSettings(from: path) }
    do {
      let discovered = try await worktrees.refresh(project)
      // Removed while git ran: the store ignores the list, and the records
      // and directory cached above must not come back for it either.
      guard workspace.project(project.id) != nil else {
        commonGitDirectories[project.id] = nil
        return
      }
      store.replaceWorktrees(discovered, forProject: project.id)
      // A worktree removed here or by hand takes its half-finished rename
      // with it; a stale id would otherwise open a field unbidden if git
      // ever listed that path again.
      if let renaming = renamingWorktreeID, workspace.worktree(renaming) == nil {
        renamingWorktreeID = nil
      }
      worktreeRecords[project.id] = records
      missingProjects.remove(project.id)
      noteSharedSettings(shared.result, stamp: shared.stamp, for: project)
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
  ///
  /// Selecting is where the question about the repository's shared hooks is
  /// asked; `byUser: false` is for the selection that follows a create,
  /// which lands while the sheet is still going away and would lose the
  /// dialog under it.
  @discardableResult
  public func select(
    _ worktree: Worktree, openingFirstTab: Bool = true, byUser: Bool = true
  )
    -> Bool
  {
    guard directoryExists(of: worktree) else { return false }
    store.selectWorktree(worktree.id)
    warmWorktrees.insert(worktree.id)
    if byUser { askAboutSharedHooksIfNeeded(for: worktree.projectID) }
    if openingFirstTab, !isBusy(worktree.id), workspace.tabs(in: worktree.id).isEmpty,
      workspace.opensTerminalOnSelect
    {
      openFirstOrNewTab(in: worktree)
    }
    sync()
    return true
  }

  /// The name the user gave this worktree, or `nil` for none.
  public func customName(of worktree: Worktree) -> String? {
    workspace.customName(of: worktree.id)
  }

  /// What a row or a header calls this worktree: the user's name where they
  /// gave one, else its branch.
  public func displayName(of worktree: Worktree) -> String {
    workspace.displayName(of: worktree)
  }

  /// The menus' Rename: the sidebar row swaps its name for a field. The
  /// project is opened first, since the item is also in the detail header's
  /// menu, where a collapsed project would leave no row to type into.
  /// Nothing for a worktree that has gone since the menu opened.
  public func beginRenaming(_ worktree: Worktree) {
    guard workspace.worktree(worktree.id) != nil else { return }
    store.setExpanded(true, forProject: worktree.projectID)
    renamingWorktreeID = worktree.id
  }

  /// The field's Return, or the focus leaving it. Ignored once the rename
  /// has ended, so the Escape that cancels is not undone by the commit that
  /// losing focus would otherwise trigger.
  public func commitRename(of id: Worktree.ID, to name: String) {
    guard renamingWorktreeID == id else { return }
    renamingWorktreeID = nil
    store.setCustomName(name, forWorktree: id)
  }

  /// The field's Escape: the name stays as it was.
  public func cancelRenaming() {
    renamingWorktreeID = nil
  }

  /// Sets or clears a name without going through the field; `nil` is the
  /// menu's Use Branch Name.
  public func renameWorktree(_ id: Worktree.ID, to name: String?) {
    renamingWorktreeID = nil
    store.setCustomName(name, forWorktree: id)
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
    if operation.step == .postCreateHook { openHeldBackTab(of: worktree) }
  }

  /// The pane's Stop Hook: ends the hook running on the worktree, which
  /// then reports itself stopped. What follows depends on the stage; see
  /// `runPostCreateHook` and `removeWorktree`.
  public func stopHook(of worktree: Worktree) {
    hookStoppers[worktree.id]?.stop()
  }

  /// The sheet's Cancel while the pre-create hook runs: nothing is created.
  public func cancelWorktreeCreation() {
    creationStopper?.stop()
  }

  public func setHookTimeoutSeconds(_ seconds: Int) {
    store.setHookTimeoutSeconds(seconds)
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
      settings: worktreeSettings(for: project))
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
    let stopper = ProcessStopper()
    creationStopper = stopper
    defer {
      worktreeCreationStep = nil
      creationStopper = nil
    }
    let resolved = resolved(project)
    let settings = worktreeSettings(for: project)
    let shell = workspace.defaultShell(for: project)
    let path: URL
    do {
      path = try await worktrees.add(
        branch: branch,
        basedOn: startPoint,
        createBranch: createBranch,
        in: resolved,
        settings: settings,
        shellPath: shell,
        timeout: workspace.hookTimeout,
        stopper: stopper,
        onStep: { [weak self] step in Task { @MainActor in self?.worktreeCreationStep = step } }
      )
    } catch {
      // The user's Cancel: nothing to report, nothing was created.
      if (error as? HookFailure)?.stop != .stopped { report(error) }
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
    if WorktreeHooks.hasScript(resolved.settings.postCreateHook) {
      worktreeOperations.begin(.postCreateHook, on: created.id)
      // Made here, not in the task: a Stop Hook clicked before the task has
      // run would otherwise find nothing to stop.
      let stopper = ProcessStopper()
      hookStoppers[created.id] = stopper
      postCreateHooks[created.id] = Task {
        await runPostCreateHook(
          for: created, branch: name, in: resolved, shellPath: shell, stopper: stopper)
      }
    }
    select(created, byUser: false)
  }

  private func runPostCreateHook(
    for worktree: Worktree, branch: String, in project: Project, shellPath: String?,
    stopper: ProcessStopper
  ) async {
    defer {
      postCreateHooks[worktree.id] = nil
      if hookStoppers[worktree.id] === stopper { hookStoppers[worktree.id] = nil }
    }
    do {
      try await worktrees?.runPostCreate(
        for: project, worktreePath: worktree.path, branch: branch, shellPath: shellPath,
        timeout: workspace.hookTimeout, stopper: stopper)
    } catch {
      let stop = (error as? HookFailure)?.stop
      // Stopped by the user: the worktree is theirs to use, as after a
      // finish. Anything else stays on the pane until dismissed, where the
      // worktree is still there to have a pane and the hook still owns it;
      // an alert otherwise.
      guard stop != .stopped else {
        if worktreeOperations.finish(.postCreateHook, on: worktree.id) {
          openHeldBackTab(of: worktree)
        }
        return
      }
      let shownInPane =
        workspace.worktree(worktree.id) != nil
        && worktreeOperations.fail(
          .postCreateHook, on: worktree.id, message: PresentedError(error).message,
          timedOut: stop != nil)
      if !shownInPane { report(error) }
      return
    }
    // A removal that began meanwhile owns the entry now.
    guard worktreeOperations.finish(.postCreateHook, on: worktree.id) else { return }
    openHeldBackTab(of: worktree)
  }

  /// The first tab was held back while the hook ran; it opens now if the
  /// worktree is still what the user is looking at, else on the next visit.
  private func openHeldBackTab(of worktree: Worktree) {
    if workspace.selectedWorktreeID == worktree.id, let current = workspace.worktree(worktree.id) {
      select(current, byUser: false)
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
      worktree, customName: customName(of: worktree),
      confirms: workspace.confirmsWorktreeRemoval,
      alwaysDeletesBranch: workspace.deletesBranchWithWorktree,
      mergeState: mergeState(of: worktree))
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

  /// The pane shows each stage while this runs: the pre-delete hook, the
  /// directory to the Trash and `git worktree prune`, the post-delete hook,
  /// the branch. What a failed stage does to the pane and the alert is
  /// `RemovalFailure`'s decision; this attaches the retry it names and puts
  /// the worktree back if it is still there.
  public func removeWorktree(_ worktree: Worktree, deletingBranch: Bool = false) async {
    guard let worktrees, let project = workspace.project(worktree.projectID) else { return }
    if renamingWorktreeID == worktree.id { renamingWorktreeID = nil }
    let resolved = resolved(project)
    worktreeOperations.begin(.init(WorktreeRemovalStep.first(for: resolved)), on: worktree.id)
    let stopper = ProcessStopper()
    hookStoppers[worktree.id] = stopper
    defer {
      if hookStoppers[worktree.id] === stopper { hookStoppers[worktree.id] = nil }
    }
    do {
      try await worktrees.remove(
        worktree, deletingBranch: deletingBranch, in: resolved,
        shellPath: workspace.defaultShell(for: project),
        trash: { [weak self] url in try await self?.moveToTrash(url) },
        timeout: workspace.hookTimeout, stopper: stopper,
        onStep: { [weak self] step in
          Task { @MainActor in self?.worktreeOperations.advance(to: .init(step), on: worktree.id) }
        })
    } catch {
      let failure = RemovalFailure.describe(
        error, deletingBranch: deletingBranch ? worktree.branch : nil)
      switch failure {
      case .stopped:
        worktreeOperations.clear(worktree.id)
        return
      case .vetoed(let message, let timedOut):
        if !worktreeOperations.fail(
          .preDeleteHook, on: worktree.id, message: message, timedOut: timedOut)
        {
          report(error)
        }
        return
      case .alert(let title, let message, let retry, let worktreeRemoved):
        var presented = PresentedError(title: title, message: message)
        if case .deleteBranchAnyway(let branch) = retry {
          presented.retryLabel = "Delete Branch Anyway"
          presented.retry = { [weak self] in
            await self?.deleteBranch(branch, of: project, force: true)
          }
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

  /// The Trash where it takes the directory; deletion where it will not, a
  /// volume without a `.Trashes` being the usual reason. The removal was
  /// confirmed either way, and the alternative is a worktree that cannot be
  /// removed from the app at all.
  func moveToTrash(_ url: URL) throws {
    do {
      try platform.moveToTrash(url)
    } catch {
      platform.log("\(url.path) could not be moved to the Trash (\(error)); deleting it")
      try FileManager.default.removeItem(at: url)
    }
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
