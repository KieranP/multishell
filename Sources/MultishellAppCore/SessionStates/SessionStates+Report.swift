import MultishellCore

/// A report over the channel read into a pane's entry and roster.
extension SessionStates {
  /// A report over the channel, `isSeen` the user looking at it. Returns what
  /// it meant once the roster is kept, `nil` for a bookkeeping tick.
  @discardableResult
  mutating func report(
    _ report: SessionStateReport, pid: Int32?, for key: Key, isSeen: Bool
  ) -> SessionState? {
    let backgroundShells = report.backgroundShells ?? []
    let resumesAfterWorkers = report.resumesAfterWorkers == true
    // Copilot's prompt mode starts its session after the first prompt. Before
    // the conversation is read, or a dropped start re-points the pane's own.
    if report.startsSession == true, report.subagentChange == nil,
      entries[key]?.workingIsShellCommand != true,
      [.running, .attention].contains(entries[key]?.state)
    {
      return nil
    }
    let (subagent, isAnotherConversation) = workerAfterReading(
      conversation: report.conversationID, named: report.subagentChange,
      reporting: report.state, for: key)
    // A prompt starts a turn, so whatever the last one left out is gone: an
    // agent interrupted, Codex aside, fires no hook and its workers send no stop.
    if report.startsTurn == true, !isAnotherConversation { update(key) { $0.startTurn() } }
    let isOwnStop = report.state == .done && subagent == nil
    if isOwnStop {
      update(key) {
        if let workersOut = report.workersOut,
          workersOut.count < SessionStateReport.maximumWorkersOut
        {
          let gone = $0.roster.keepOnly(workersOut, shells: backgroundShells)
          for id in gone { $0.promptRaisers.remove(.worker(id)) }
        } else {
          $0.roster.keepShells(backgroundShells)
        }
        $0.resumesAfterWorkers = resumesAfterWorkers
      }
    }
    guard
      let state = meaning(
        of: report.state, subagent: subagent,
        turnFollows: isOwnStop && report.turnFollows == true, for: key)
    else { return nil }
    switch state {
    case .idle:
      clear(key)
    case .done, .failed:
      landFinished(state, on: key, isSeen: isSeen)
      // Written again, a Stop with nothing out having landed on an empty entry.
      if isOwnStop { update(key) { $0.resumesAfterWorkers = resumesAfterWorkers } }
    case .running, .attention:
      update(key) {
        $0.state = state
        if let pid { $0.pid = pid }
      }
    }
    update(key) {
      $0.workingIsShellCommand = report.isFromShellIntegration == true && $0.state == .running
    }
    noteIfStanding(
      SessionNote(state: state, message: report.message, duration: report.duration), on: key)
    return state
  }

  /// A report's worker once its conversation is read: a worker's end can
  /// hand back the pane's own id, and another conversation is a worker.
  private mutating func workerAfterReading(
    conversation conversationID: String?, named subagent: SubagentReport?,
    reporting state: SessionState, for key: Key
  ) -> (subagent: SubagentReport?, isAnotherConversation: Bool) {
    guard let conversationID else { return (subagent, false) }
    // A worker's end names the conversation it ran under: the pane's own, where
    // a pane that heard the worker first took the worker for its own.
    if let ending = subagent, ending.phase == .ended, ownConversationIDs[key] == ending.id {
      ownConversationIDs[key] = conversationID
      update(key) { $0.roster.forget(conversationID) }
    }
    guard subagent == nil,
      let worker = worker(inConversation: conversationID, reporting: state, for: key)
    else { return (subagent, false) }
    return (worker, true)
  }

  /// A finished state lands unless the user is looking and looking clears
  /// it; the process it was about is dropped either way.
  mutating func landFinished(_ state: SessionState, on key: Key, isSeen: Bool) {
    update(key) {
      $0.state = isSeen && state.clearsWhenSeen ? nil : state
      $0.pid = nil
    }
  }

  /// Only where a state survived: a Done about a tab the user is looking at
  /// leaves nothing to say something about.
  private mutating func noteIfStanding(_ note: SessionNote, on key: Key) {
    guard entries[key]?.state != nil else { return }
    update(key) { $0.note = note }
  }

  /// The worker a report of another conversation's is, or `nil` for the
  /// pane's own. Only the pane's own sends a start, an end or a Stop.
  private mutating func worker(
    inConversation conversation: String, reporting state: SessionState, for key: Key
  ) -> SubagentReport? {
    let own = ownConversationIDs[key]
    guard own == nil || state == .idle || state.isFinished else {
      return own == conversation ? nil : SubagentReport(id: conversation, phase: .working)
    }
    if let own, own != conversation {
      // A new conversation of the pane's, cleared or started without a
      // SessionStart, was read as a worker until now.
      update(key) { $0.roster.forget(conversation) }
    }
    ownConversationIDs[key] = conversation
    return nil
  }
}
