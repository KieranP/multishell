import MultishellCore

/// The tab each action runs in, found by the name its session carries.
extension AppModel {
  /// The tab an action last ran in here, if it is still open.
  func actionSession(named name: String, in worktreeID: Worktree.ID) -> TerminalSession? {
    workspace.sessions(in: worktreeID).first { $0.actionName == name }
  }

  /// Whether something runs in an action's tab: its own run, or whatever the
  /// shell after it started, an agent idle at its prompt included.
  func isOccupied(actionSession id: TerminalSession.ID) -> Bool {
    actionRunStarts[id] != nil
      || sessionStates.state(ofSessions: [id])?.isUnderway == true
      || workspace.session(id).flatMap(agentIDAtThePrompt) != nil
  }

  func actionRunState(of name: String, in worktreeID: Worktree.ID) -> ActionRunState {
    guard let session = actionSession(named: name, in: worktreeID) else { return .idle }
    if let start = actionRunStarts[session.id] { return .running(since: start) }
    switch sessionStates.state(ofSessions: [session.id]) {
    case .done: return .done
    case .failed: return .failed
    case .attention, .idle, .running, nil: return .idle
    }
  }
}
