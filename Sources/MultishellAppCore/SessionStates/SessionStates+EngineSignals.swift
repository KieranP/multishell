import MultishellCore

extension SessionStates {
  /// A bell or a title from the engine: something happened, not what. It
  /// never downgrades a state the occupant reported.
  mutating func noteActivity(in id: TerminalSession.ID, isSeen: Bool) {
    let key = Key.session(id)
    // A program's own report outranks it: an idle one says nothing happened.
    guard entries[key]?.state == nil, !isHeldByProgram(key), !isSeen
    else { return }
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
    endProgramHold(on: key)
    ownConversationIDs[key] = nil
    // A finish the program announced is not announced again, and a later
    // command's end spends it; see agents/program-status.md.
    let announced = entries[key]?.finishAnnouncedForCommandEnd
    update(key) { stored in
      // An agent killed with a worker out sends no SubagentStop; the command
      // it was has returned, so nothing is out and nothing is owed.
      stored.settleTurn()
      stored.finishAnnouncedForCommandEnd = nil
      if announced == nil { stored.finishAnnouncedForShellReport = nil }
    }
    if let announced, finished.repeatsFinish(announced: announced) { return }
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
