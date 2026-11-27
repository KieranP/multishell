import MultishellCore

/// Which actions a worktree runs: the user's own over the file's, as trusted.
extension AppModel {
  /// The actions a worktree's project has in force, in menu order. A row the
  /// Actions page has not filled in yet is not one.
  func actionsInForce(for worktree: Worktree) -> [ProjectAction] {
    (effectiveProject(of: worktree)?.settings.actions ?? []).filter(\.isFilledIn)
  }

  /// The actions in force may have moved: their keys are taken from the panes
  /// or given back, and a restart question about one gone goes with it.
  func noteActionsInForceChanged() {
    applyTerminalConfiguration()
    settlePendingActionRestart()
    settleActionKeysRecording()
  }

  /// Whether one of the user's own actions, filled in, stands in for the
  /// file's action of this name, for the Actions page's note on its row.
  public func ownActionStandsIn(forFileAction name: String, in project: Project) -> Bool {
    ownActionNamesStandingIn(in: currentCopy(of: project)).contains(name)
  }

  /// The names of the user's own actions filled in, each standing in for the file's of its name.
  func ownActionNamesStandingIn(in project: Project) -> Set<String> {
    Set(project.settings.actions.filter(\.isFilledIn).map(\.name))
  }
}
