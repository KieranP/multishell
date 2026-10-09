import MultishellCore

extension AppModel {
  /// Entry point from the UI. Always asks: removal closes every live
  /// terminal in the project's worktrees, with no undo.
  public func requestProjectRemoval(_ project: Project, from source: PendingProjectRemoval.Source) {
    pendingProjectRemoval = PendingProjectRemoval(project: project, source: source)
  }

  /// Each window attaches the dialog with its own source, so only the
  /// window that asked presents it.
  public func pendingProjectRemoval(
    for source: PendingProjectRemoval.Source
  ) -> PendingProjectRemoval? {
    pendingProjectRemoval.flatMap { $0.source == source ? $0 : nil }
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
    defaultBranches[project.id] = nil
    // Paths are ids, so the project re-added under the same filter text came back collapsed.
    setIfChanged(
      \.projectsCollapsedWhileFiltering,
      projectsCollapsedWhileFiltering.subtracting([project.id]),
    )
    // Or a project re-added while git still cannot read it would be dimmed
    // with no alert: the first failure is what reports one.
    missingProjects.remove(project.id)
    commonGitDirectories[project.id] = nil
    worktreeRecords[project.id] = nil
    worktreeSortCache.forget(project.id)
    dismissSharedSettingsTrust(for: project.id)
    // Or the settings window's fallback to the current project never fires:
    // a stale id wins over it, and the window opens only to dismiss itself.
    if requestedSettingsProjectID == project.id { requestedSettingsProjectID = nil }
    // The sheet this project's windows left standing, the settings window
    // being its own scene. A stale sheet's Create would add a real worktree.
    if newWorktreeRequest?.projectID == project.id { newWorktreeRequest = nil }
    forgetWorktrees(store.removeProject(project.id))
    reconcileSessions(takingFocus: true)
    Task { await rearmWatcher() }
  }
}
