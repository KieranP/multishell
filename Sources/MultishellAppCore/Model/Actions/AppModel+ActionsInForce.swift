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
    currentCopy(of: project).settings.actions.contains { $0.isFilledIn && $0.name == name }
  }

  /// Keys are stored by name, so an own row of the name, filled in or not, has
  /// the one keys cell: two would record at once.
  public func fileRowShowsKeys(forFileAction name: String, in project: Project) -> Bool {
    !ownSettings(of: project).actions.contains { $0.name == name }
  }
}
