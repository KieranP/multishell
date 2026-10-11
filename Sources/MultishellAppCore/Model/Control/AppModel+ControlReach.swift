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

  /// Its worktree selected where it is not in view, as a click on the row.
  func refusalToBringIntoView(_ tab: TerminalTab) -> ControlRefusal? {
    guard let worktree = workspace.worktree(tab.worktreeID),
      isInView(worktree) || select(worktree, openingFirstTab: .never)
    else { return .worktreeNotReady(id: ControlID.worktree(tab.worktreeID)) }
    return nil
  }
}
