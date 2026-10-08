import MultishellCore

extension AppModel {
  public func clearState(of tab: TerminalTab) {
    mutateStates { $0.clear(sessions: tab.sessionIDs, worktree: nil) }
    updatePIDWatch()
  }

  /// One pane's own dot, for a card whose agent is long gone. The worktree's
  /// clear beside it takes every pane at once.
  public func clearState(ofPane id: TerminalSession.ID) {
    mutateStates { $0.clear(.session(id)) }
    updatePIDWatch()
  }

  public func clearState(ofWorktree id: Worktree.ID) {
    mutateStates { $0.clear(sessions: workspace.sessions(in: id).map(\.id), worktree: id) }
    updatePIDWatch()
  }
}
