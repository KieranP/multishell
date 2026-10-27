import MultishellCore

extension AppModel {
  /// A pane a request acts in must be there and have its shell running.
  func refusalToReachLivePane(_ id: TerminalSession.ID) -> ControlRefusal? {
    refusalToReachPane(id) ?? (liveSessionIDs.contains(id) ? nil : .paneNotLive(id: id))
  }

  /// Only that it is there: the engine says whether its shell runs.
  func refusalToReachPane(_ id: TerminalSession.ID) -> ControlRefusal? {
    workspace.tab(owning: id) == nil ? .noPane(id: id) : nil
  }

  /// Turns the store to a tab or pane and hands it the keyboard, selecting its
  /// worktree where it is not in view, as a click on the row; else the refusal.
  func bringIntoView(_ worktreeID: Worktree.ID, turning turn: () -> Void) -> ControlRefusal? {
    if let worktree = workspace.worktree(worktreeID) {
      if isInView(worktree) {
        turn()
        reconcileSessions(takingFocus: true)
        return nil
      }
      if select(worktree, openingFirstTab: .never, turning: turn) { return nil }
    }
    return .worktreeNotReady(id: ControlID.worktree(worktreeID))
  }
}
