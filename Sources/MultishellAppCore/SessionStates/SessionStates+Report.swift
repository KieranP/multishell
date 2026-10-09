import MultishellCore

/// A report over the channel read into a pane's entry and roster.
extension SessionStates {
  /// A report over the channel, `isSeen` the user looking at it. Returns what
  /// it meant once the roster is kept, `nil` for a bookkeeping tick.
  @discardableResult
  mutating func apply(
    _ report: SessionStateReport,
    pid: Int32?,
    for key: Key,
    isSeen: Bool,
  ) -> SessionState? {
    let resumesAfterWorkers = report.resumesAfterWorkers == true
    // Copilot's prompt mode starts its session after the first prompt, so a start
    // on a pane already working is dropped before it can re-point the conversation.
    if report.startsSession == true, report.workerChange == nil,
      entries[key]?.workingIsShellCommand != true,
      [.running, .attention].contains(entries[key]?.state)
    {
      return nil
    }
    let (worker, isAnotherConversation) = workerAfterReading(
      conversation: report.conversationID,
      named: report.workerChange,
      reporting: report.state,
      for: key,
    )
    // A prompt starts a turn, so whatever the last one left out is gone: an
    // agent interrupted, Codex aside, fires no hook and its workers send no stop.
    if report.startsTurn == true, !isAnotherConversation { update(key) { $0.startTurn() } }
    let isOwnStop = report.state == .done && worker == nil
    if isOwnStop { syncRoster(toStop: report, for: key) }
    if let worker { syncRoster(toWorkersStop: report, stopping: worker.id, for: key) }
    if let launched = report.launched { update(key) { $0.roster.recordLaunch(launched) } }
    if let killed = report.killedTaskID {
      update(key) { entry in
        entry.forgetPrompts(ofWorkers: entry.roster.recordKill(killed))
      }
    }
    guard
      let state = applyRoster(
        to: report.state,
        worker: worker,
        turnFollows: isOwnStop && report.turnFollows == true,
        for: key,
      )
    else { return nil }
    switch state {
    case .idle:
      clear(key)

    case .done, .failed:
      landFinished(state, on: key, isSeen: isSeen)
      // Written again, a Stop with nothing out having landed on an empty entry.
      if isOwnStop { update(key) { $0.resumesAfterWorkers = resumesAfterWorkers } }

    case .running, .attention:
      update(key) { entry in
        entry.state = state
        if let pid { entry.pid = pid }
      }
    }
    update(key) { entry in
      entry.workingIsShellCommand = report.isFromShellIntegration == true && entry.state == .running
    }
    noteIfStanding(
      SessionNote(state: state, message: report.shownMessage, duration: report.duration),
      on: key,
    )
    return state
  }

  /// The workers an agent's own Stop lists are all that is out; with no
  /// list, or one cut at the cap, its background shells are only added.
  private mutating func syncRoster(toStop report: SessionStateReport, for key: Key) {
    let backgroundShells = report.backgroundShells ?? []
    update(key) { entry in
      if let workersOut = report.completeWorkersOut {
        entry.forgetPrompts(ofWorkers: entry.roster.keepOnly(workersOut, shells: backgroundShells))
      } else {
        entry.roster.recordShells(backgroundShells)
      }
      entry.resumesAfterWorkers = report.resumesAfterWorkers == true
    }
  }

  /// A worker's stop lists the agent's background work, which ends what an
  /// earlier list named and this one leaves out.
  private mutating func syncRoster(
    toWorkersStop report: SessionStateReport,
    stopping workerID: String,
    for key: Key,
  ) {
    guard let workersOut = report.completeWorkersOut else { return }
    update(key) { entry in
      entry.forgetPrompts(
        ofWorkers: entry.roster.keepOnlyListedOut(workersOut, stopping: workerID)
      )
    }
  }

  /// A report's worker once its conversation is read: a worker's end can
  /// hand back the pane's own id, and another conversation is a worker.
  private mutating func workerAfterReading(
    conversation conversationID: String?,
    named worker: WorkerReport?,
    reporting state: SessionState,
    for key: Key,
  ) -> (worker: WorkerReport?, isAnotherConversation: Bool) {
    guard let conversationID else { return (worker, false) }
    // A worker's end names the conversation it ran under: the pane's own, where
    // a pane that heard the worker first took the worker for its own.
    if let ending = worker, ending.phase == .ended, ownConversationIDs[key] == ending.id {
      ownConversationIDs[key] = conversationID
      update(key) { $0.roster.forget(conversationID) }
    }
    guard worker == nil,
      let worker = self.worker(inConversation: conversationID, reporting: state, for: key)
    else { return (worker, false) }
    return (worker, true)
  }

  /// A finished state lands unless the user is looking and looking clears
  /// it; the process it was about is dropped either way.
  mutating func landFinished(_ state: SessionState, on key: Key, isSeen: Bool) {
    update(key) { entry in
      entry.state = isSeen && state.clearsWhenSeen ? nil : state
      entry.pid = nil
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
    inConversation conversation: String,
    reporting state: SessionState,
    for key: Key,
  ) -> WorkerReport? {
    let own = ownConversationIDs[key]
    guard own == nil || state == .idle || state.isFinished else {
      return own == conversation ? nil : WorkerReport(id: conversation, phase: .working)
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
