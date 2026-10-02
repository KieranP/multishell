import MultishellCore

/// What a report means once the roster of workers is kept, and the Done a
/// Stop owes while workers are out; see Docs/design/agents.md.
extension SessionStates {
  /// `nil` for a report that moves nothing.
  mutating func meaning(
    of state: SessionState, subagent: SubagentReport?, turnFollows: Bool, for key: Key
  ) -> SessionState? {
    // A Stop, a failure or an end naming a worker, which no agent documents,
    // is the agent's own and puts no phantom on the roster.
    guard let subagent, !state.isFinished, state != .idle else {
      return meaningOfOwnReport(
        state, entry: entries[key] ?? Entry(), turnFollows: turnFollows, for: key)
    }
    var place = SubagentRoster.Place(id: subagent.id)
    update(key) {
      let before = $0.roster.subagents.workerCount
      place = $0.record(subagent)
      // An idle agent takes a turn over this end, and that turn's Stop pays;
      // an end that took nobody off woke nothing.
      if subagent.phase == .ended, subagent.wakesAgent != false, $0.displaced == .owedDone,
        $0.roster.subagents.workerCount < before
      {
        $0.turnUnderway = true
      }
    }
    let entry = entries[key] ?? Entry()
    let raiser = Entry.PromptRaiser.worker(place.id)
    switch state {
    case .attention:
      update(key) {
        $0.rememberDisplaced(byPrompt: true)
        $0.promptRaisers.insert(raiser)
      }
      return state
    case .running where subagent.phase == .working:
      // A failure stands to mere work, and so does another thread's prompt:
      // only the thread that asked, moving on, says it was answered.
      if entry.state == .failed { return nil }
      if entry.state == .attention {
        guard answer(raiser, sharedPlace: place.isShared, for: key) else { return nil }
      }
      update(key) { $0.rememberDisplaced(byPrompt: false) }
      return state
    case .running:
      return meaningOfTick(subagent, place: place, entry: entry, for: key)
    case .done, .failed, .idle:
      return nil
    }
  }

  /// A start or an end carries `.running` for want of anything to say: a
  /// tick, not news, except over a Done or nothing, and at the last one out.
  private mutating func meaningOfTick(
    _ subagent: SubagentReport, place: SubagentRoster.Place, entry: Entry, for key: Key
  ) -> SessionState? {
    let raiser = Entry.PromptRaiser.worker(place.id)
    let outstanding = !entry.roster.subagents.isEmpty
    // A worker ending with its prompt still up, the user having denied it,
    // takes the prompt with it.
    if subagent.phase == .ended, entry.state == .attention, entry.promptRaisers.contains(raiser) {
      guard answer(raiser, sharedPlace: place.isShared, for: key) else { return nil }
      if !outstanding, let displaced = entry.displaced {
        return settleLastWorkerOut(displaced, entry: entry, for: key)
      }
      return .running
    }
    if !outstanding, let displaced = entry.displaced {
      return settleLastWorkerOut(displaced, entry: entry, for: key)
    }
    if outstanding, entry.state == nil || entry.state == .done {
      update(key) { $0.rememberDisplaced(byPrompt: false) }
      return .running
    }
    guard entry.state == .running else { return nil }
    return .running
  }

  /// The agent's own report. Its Working answers its own prompt and takes
  /// the dot back from a worker; its Stop is held while workers are out.
  private mutating func meaningOfOwnReport(
    _ state: SessionState, entry: Entry, turnFollows: Bool, for key: Key
  ) -> SessionState? {
    // Its Working is a turn running and its Stop the end of one; its prompt
    // says neither, and may be a worker's filed as its own.
    if state != .attention { update(key) { $0.turnUnderway = state == .running } }
    switch state {
    case .running:
      // The claim goes whether or not another thread's prompt still holds the
      // dot, or the last worker out puts back what the turn began over.
      update(key) { if $0.displaced != .owedDone { $0.displaced = nil } }
      if entry.state == .attention {
        guard answer(.agent, for: key) else { return nil }
      }
      return state
    case .attention:
      // The agent asking claims a Working a worker put over nothing; a Done
      // it owed is still owed.
      update(key) {
        if $0.displaced == .nothing { $0.displaced = nil }
        $0.promptRaisers.insert(.agent)
      }
      return state
    // A turn starting straight after the Stop is work out as a worker is.
    case .done where !entry.roster.subagents.isEmpty || turnFollows:
      update(key) { $0.roster.markOutAtStop() }
      // A failure is left alone whether a worker's prompt covered it or it is
      // still standing, or the Done would be paid over it.
      guard entry.state != .failed else { return nil }
      // The main loop stopping is not the turn finishing: the Done is owed to
      // the last worker out, and a worker's prompt still up stays on the dot.
      update(key) {
        if $0.displaced?.isFailure != true { $0.displaced = .owedDone }
        if turnFollows { $0.turnUnderway = true }
      }
      if entry.state == .attention, entry.promptRaisers.contains(where: { $0 != .agent }) {
        update(key) { _ = $0.answer(.agent) }
        return nil
      }
      update(key) { $0.promptRaisers = [] }
      return .running
    case .done:
      update(key) { $0.clearDisplaced() }
      return state
    case .idle, .failed:
      update(key) { $0.settleTurn() }
      return state
    }
  }

  /// `true` once no other raiser's prompt still holds the dot.
  private mutating func answer(
    _ raiser: Entry.PromptRaiser, sharedPlace: Bool = false, for key: Key
  ) -> Bool {
    var answered = false
    update(key) { answered = $0.answer(raiser, sharedPlace: sharedPlace) }
    return answered
  }

  /// The last worker out pays what its agent's Stop owed, unless an end woke
  /// that agent for a turn: that turn's Stop pays it instead.
  private mutating func settleLastWorkerOut(
    _ displaced: Entry.Displaced, entry: Entry, for key: Key
  ) -> SessionState? {
    guard displaced == .owedDone, entry.resumesAfterWorkers, entry.turnUnderway else {
      return restore(displaced, for: key)
    }
    update(key) { $0.clearDisplaced() }
    return entry.state == .running ? nil : .running
  }

  /// The last worker out puts back what the first displaced: a Done is paid
  /// and announced, nothing is cleared, a failure was announced when it happened.
  private mutating func restore(_ displaced: Entry.Displaced, for key: Key) -> SessionState? {
    update(key) { $0.clearDisplaced() }
    switch displaced {
    case .nothing: return .idle
    case .done, .owedDone: return .done
    case .failed(let note, let since):
      update(key) {
        $0.state = .failed
        $0.pid = nil
        $0.note = note
        $0.since = since
      }
      return nil
    }
  }
}
