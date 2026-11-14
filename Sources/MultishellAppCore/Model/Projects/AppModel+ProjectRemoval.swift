import MultishellCore

extension AppModel {
  /// Entry point from the UI. Always asks: removal closes every live
  /// terminal in the project's worktrees, with no undo.
  public func requestProjectRemoval(_ project: Project, from window: DialogWindow) {
    pendingProjectRemoval = PendingProjectRemoval(project: project, window: window)
  }

  /// Each window attaches the dialog for itself, so only the
  /// window that asked presents it.
  public func pendingProjectRemoval(
    for window: DialogWindow
  ) -> PendingProjectRemoval? {
    pendingProjectRemoval.flatMap { $0.window == window ? $0 : nil }
  }

  public func answerProjectRemoval(_ pending: PendingProjectRemoval, confirmed: Bool) {
    pendingProjectRemoval = nil
    if confirmed { removeProject(pending.project) }
  }

  /// What the confirmation says, with the live terminal count.
  public func projectRemovalMessage(for project: Project) -> String {
    let live = workspace.worktrees(of: project.id).map { liveTerminalCount(in: $0.id) }
    return PendingProjectRemoval.message(liveTerminals: live.reduce(0, +))
  }

  func removeProject(_ project: Project) {
    defaultBranchScans[project.id] = nil
    detectedDefaultBranchNames[project.id] = nil
    forgetServices(ofProject: project.id)
    // Paths are ids, so the project re-added under the same filter text came back collapsed.
    setIfChanged(
      \.projectsCollapsedWhileFiltering,
      projectsCollapsedWhileFiltering.subtracting([project.id]),
    )
    expandedHiddenSections.remove(project.id)
    // Or a project re-added while git still cannot read it would be dimmed
    // with no alert: the first failure is what reports one.
    missingProjects.remove(project.id)
    commonGitDirectories[project.id] = nil
    worktreeRecords[project.id] = nil
    worktreeListReads.forget(project.id)
    sharedSettingsReads.forget(project.id)
    worktreeSortCache.forget(project.id)
    dismissSharedSettingsTrust(for: project.id)
    // Or the settings window would stay on a project it can no longer show.
    if settingsLocation.scope == .project(project.id) { returnSettingsToAllProjects() }
    // The sheet this project's windows left standing, the settings window
    // being its own scene. A stale sheet's Create would add a real worktree.
    if newWorktreeRequest?.projectID == project.id { newWorktreeRequest = nil }
    stageHandles.stopCreations(in: project.id)
    if pendingProjectRemoval?.project.id == project.id { pendingProjectRemoval = nil }
    // Only the view changing hands the keyboard on; see Docs/design/architecture.md.
    let wasInView = worktreeInView?.projectID == project.id
    let removed = store.removeProject(project.id)
    releaseReviewFiles(of: removed)
    forgetWorktrees(removed)
    reconcileSessions(takingFocus: wasInView)
    Task { await rearmWatcher() }
  }
}
