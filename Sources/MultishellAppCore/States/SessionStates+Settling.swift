import MultishellCore

/// What a report means once the roster of workers is kept, and the Done a
/// Stop owes while workers are out; see Docs/design/agents.md.
extension SessionStates {
  /// What a report means once the roster is kept, `nil` for one that moves
  /// nothing. See Docs/design/agents.md.
  mutating func meaning(
    of state: SessionState, subagent: SubagentReport?, for key: Key
  ) -> SessionState? {
    // A Stop, a failure or an end naming a worker, which no agent documents,
    // is the agent's own and puts no phantom on the roster.
    guard let subagent, !state.isFinished, state != .idle else {
      return meaningOfOwnReport(state, entry: entries[key] ?? Entry(), for: key)
    }
    var place = Entry.Place(id: subagent.id)
    update(key) {
      place = $0.keep(subagent)
      // A worker out holds the Done itself; the last one out waits again.
      if !$0.subagents.isEmpty { $0.awaitingResume = false }
    }
    let entry = entries[key] ?? Entry()
    let raiser = Entry.Raiser.worker(place.id)
    switch state {
    case .attention:
      update(key) {
        $0.rememberDisplaced(byPrompt: true)
        $0.waitingRaisers.insert(raiser)
      }
      return state
    case .running where subagent.phase == .working:
      // A failure stands to mere work, and so does another thread's prompt:
      // only the thread that asked, moving on, says it was answered.
      if entry.state == .error { return nil }
      if entry.state == .attention {
        var answered = false
        update(key) { answered = $0.answered(raiser, sharedPlace: place.isShared) }
        guard answered else { return nil }
      }
      update(key) { $0.rememberDisplaced(byPrompt: false) }
      return state
    case .running:
      return meaningOfTick(subagent, place: place, entry: entry, for: key)
    case .done, .error, .idle:
      return nil
    }
  }

  /// A start or an end carries `.running` for want of anything to say: a
  /// tick, not news, except over a Done or nothing, and at the last one out.
  private mutating func meaningOfTick(
    _ subagent: SubagentReport, place: Entry.Place, entry: Entry, for key: Key
  ) -> SessionState? {
    let raiser = Entry.Raiser.worker(place.id)
    let outstanding = !entry.subagents.isEmpty
    // A worker ending with its prompt still up, the user having denied it,
    // takes the prompt with it.
    if subagent.phase == .ended, entry.state == .attention, entry.waitingRaisers.contains(raiser) {
      var answered = false
      update(key) { answered = $0.answered(raiser, sharedPlace: place.isShared) }
      guard answered else { return nil }
      if !outstanding, let displaced = entry.displaced {
        return lastOut(displaced, entry: entry, for: key)
      }
      return .running
    }
    if !outstanding, let displaced = entry.displaced {
      return lastOut(displaced, entry: entry, for: key)
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
    _ state: SessionState, entry: Entry, for key: Key
  ) -> SessionState? {
    // Any report of the agent's own is the turn it was awaited for.
    update(key) { $0.awaitingResume = false }
    switch state {
    case .running:
      // The claim goes whether or not another thread's prompt still holds the
      // dot, or the last worker out puts back what the turn began over.
      update(key) { if $0.displaced != .stop { $0.displaced = nil } }
      if entry.state == .attention {
        var answered = false
        update(key) { answered = $0.answered(.agent) }
        guard answered else { return nil }
      }
      return state
    case .attention:
      // The agent asking claims a Working a worker put over nothing; a Done
      // it owed is still owed.
      update(key) {
        if $0.displaced == .nothing { $0.displaced = nil }
        $0.waitingRaisers.insert(.agent)
      }
      return state
    case .done where !entry.subagents.isEmpty:
      // A failure is left alone whether a worker's prompt covered it or it is
      // still standing, or the Done would be paid over it.
      guard entry.state != .error else { return nil }
      // The main loop stopping is not the turn finishing: the Done is owed to
      // the last worker out, and a worker's prompt still up stays on the dot.
      update(key) { if $0.displaced?.isFailure != true { $0.displaced = .stop } }
      if entry.state == .attention, entry.waitingRaisers.contains(where: { $0 != .agent }) {
        update(key) { _ = $0.answered(.agent) }
        return nil
      }
      update(key) { $0.waitingRaisers = [] }
      return .running
    case .done:
      update(key) {
        $0.displaced = nil
        $0.waitingRaisers = []
      }
      return state
    case .idle, .error:
      update(key) { $0.settleTurn() }
      return state
    }
  }

  /// The last worker out pays what its agent's Stop owed, unless that agent
  /// takes a turn when its workers end: that turn's Stop pays it instead.
  private mutating func lastOut(
    _ displaced: Entry.Displaced, entry: Entry, for key: Key
  ) -> SessionState? {
    guard displaced == .stop, entry.stopResumes else { return restore(displaced, for: key) }
    update(key) {
      $0.awaitingResume = true
      $0.waitingRaisers = []
    }
    return entry.state == .running ? nil : .running
  }

  /// The awaited turn never came, so its Done is paid now.
  mutating func payOverdueResume(_ key: Key, isSeen: Bool) -> SessionState? {
    guard entries[key]?.awaitingResume == true, let displaced = entries[key]?.displaced else {
      return nil
    }
    update(key) { $0.awaitingResume = false }
    guard let state = restore(displaced, for: key) else { return nil }
    update(key) {
      $0.state = isSeen && state.clearsWhenSeen ? nil : state
      $0.pid = nil
    }
    if entries[key]?.state != nil {
      update(key) { $0.note = SessionNote(state: state, message: nil, duration: nil) }
    }
    return state
  }

  var keysAwaitingResume: Set<Key> { Set(entries.filter(\.value.awaitingResume).keys) }

  /// The last worker out puts back what the first displaced: a Done is paid
  /// and announced, nothing is cleared, a failure was announced when it happened.
  private mutating func restore(_ displaced: Entry.Displaced, for key: Key) -> SessionState? {
    update(key) {
      $0.displaced = nil
      $0.waitingRaisers = []
    }
    switch displaced {
    case .nothing: return .idle
    case .done, .stop: return .done
    case .failed(let note, let since):
      update(key) {
        $0.state = .error
        $0.pid = nil
        $0.note = note
        $0.since = since
      }
      return nil
    }
  }
}
