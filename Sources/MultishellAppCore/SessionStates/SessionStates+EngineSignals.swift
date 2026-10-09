import MultishellCore

extension SessionStates {
  /// A bell or a title from the engine: something happened, not what. It
  /// never downgrades a state the occupant reported.
  mutating func noteActivity(in id: TerminalSession.ID, isSeen: Bool) {
    let key = Key.session(id)
    guard entries[key]?.state == nil, !isSeen else { return }
    update(key) { $0.state = .done }
  }

  /// The shell's foreground command returned: the one engine signal that
  /// outranks a report. A non-zero exit is Failed, and covers a Done.
  mutating func noteCommandFinished(
    in id: TerminalSession.ID,
    exitCode: Int32?,
    isSeen: Bool,
  ) {
    let key = Key.session(id)
    let finished = SessionState.finished(exitCode: exitCode)
    // An agent killed with a worker out sends no SubagentStop; the command
    // it was has returned, so nothing is out and nothing is owed.
    update(key) { $0.settleTurn() }
    ownConversationIDs[key] = nil
    switch entries[key]?.state {
    case .running, .attention, nil:
      landFinished(finished, on: key, isSeen: isSeen)

    case .done:
      if finished == .failed { update(key) { $0.state = .failed } }

    case .failed, .idle:
      break
    }
  }
}
