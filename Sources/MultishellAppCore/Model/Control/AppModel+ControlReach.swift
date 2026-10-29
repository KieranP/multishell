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

  /// A terminal tab, which has panes and a title of its own to set.
  func reachTerminalTab(_ id: WorkspaceTab.ID) throws(ControlRefusal) -> TerminalTab {
    guard let tab = workspace.tab(id) else {
      throw workspace.fileTab(id) == nil ? .noTab(id: id) : .tabShowsAFile(id: id)
    }
    return tab
  }

  /// A file tab, which has a bar to step and find in.
  func refusalToReachFileTab(_ id: WorkspaceTab.ID) -> ControlRefusal? {
    guard workspace.fileTab(id) == nil else { return nil }
    return workspace.tab(id) == nil ? .noTab(id: id) : .tabShowsNoFile(id: id)
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
