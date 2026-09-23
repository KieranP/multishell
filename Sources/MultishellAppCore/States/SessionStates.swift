import Foundation
import MultishellCore

/// What each live terminal is doing, and who clears what. Runtime only; see
/// Docs/design/agents.md.
public struct SessionStates: Equatable, Sendable {
  public enum Key: Hashable, Sendable {
    case session(TerminalSession.ID)
    /// A report that named only a directory: a hook fired from another
    /// terminal in that worktree.
    case worktree(Worktree.ID)
  }

  private var entries: [Key: Entry] = [:]

  public init() {}

  public subscript(key: Key) -> SessionState? { entries[key]?.state }

  public func since(_ key: Key) -> Date? { entries[key]?.since }
  public func note(_ key: Key) -> SessionNote? { entries[key]?.note }

  public var states: [Key: SessionState] { entries.compactMapValues(\.state) }
  var pids: [Key: Int32] { entries.compactMapValues(\.pid) }
  public var since: [Key: Date] { entries.compactMapValues(\.since) }
  var notes: [Key: SessionNote] { entries.compactMapValues(\.note) }

  /// The workers out under one key, oldest first.
  public func subagents(_ key: Key) -> [Subagent] { entries[key]?.workers ?? [] }

  /// An entry with nothing left in it goes, so `isEmpty` and `==` read true.
  private mutating func update(_ key: Key, _ change: (inout Entry) -> Void) {
    var entry = entries[key] ?? Entry()
    change(&entry)
    entries[key] = entry.isEmpty ? nil : entry
  }

  /// A report over the channel, `isSeen` the user looking at it. Returns what
  /// it meant once `settling` has kept the roster, `nil` for a bookkeeping tick.
  @discardableResult
  public mutating func report(
    _ state: SessionState, pid: Int32?, message: String? = nil, duration: Double? = nil,
    subagent: SubagentReport? = nil, startsTurn: Bool = false, backgroundShells: [Int32] = [],
    resumesAfterWorkers: Bool = false, for key: Key, isSeen: Bool
  ) -> SessionState? {
    // A prompt starts a turn, so whatever the last one left out is gone: an
    // agent interrupted fires no hook and its workers send no stop.
    if startsTurn { update(key) { $0.settleTurn() } }
    if state == .done, subagent == nil {
      update(key) {
        $0.keepShells(backgroundShells)
        $0.stopResumes = resumesAfterWorkers
      }
    }
    guard let state = settling(state, subagent: subagent, for: key) else { return nil }
    switch state {
    case .idle:
      clear(key)
    case .done, .error:
      update(key) {
        $0.state = isSeen && state.clearsWhenSeen ? nil : state
        $0.pid = nil
      }
    case .running, .attention:
      update(key) {
        $0.state = state
        if let pid { $0.pid = pid }
      }
    }
    // Only where a state survived the report: a Done about a tab the user is
    // looking at leaves nothing to say something about.
    if entries[key]?.state != nil {
      update(key) { $0.note = SessionNote(state: state, message: message, duration: duration) }
    }
    return state
  }

  /// What a report means once the roster is kept, `nil` for one that moves
  /// nothing. See Docs/design/agents.md.
  private mutating func settling(
    _ state: SessionState, subagent: SubagentReport?, for key: Key
  ) -> SessionState? {
    // A Stop, a failure or an end naming a worker, which no agent documents,
    // is the agent's own and puts no phantom on the roster.
    guard let subagent, !state.isFinished, state != .idle else {
      return settlingOwn(state, entry: entries[key] ?? Entry(), for: key)
    }
    var place = Entry.Place(id: subagent.id)
    update(key) {
      place = $0.keep(subagent)
      // A worker out holds the Done itself; the last one out waits again.
      if !$0.workers.isEmpty { $0.awaitingResume = false }
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
      return settlingTick(subagent, place: place, entry: entry, for: key)
    case .done, .error, .idle:
      return nil
    }
  }

  /// A start or an end carries `.running` for want of anything to say: a
  /// tick, not news, except over a Done or nothing, and at the last one out.
  private mutating func settlingTick(
    _ subagent: SubagentReport, place: Entry.Place, entry: Entry, for key: Key
  ) -> SessionState? {
    let raiser = Entry.Raiser.worker(place.id)
    let outstanding = !entry.workers.isEmpty
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
  private mutating func settlingOwn(
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
    case .done where !entry.workers.isEmpty:
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
    case .failed(let note):
      update(key) {
        $0.state = .error
        $0.pid = nil
        $0.note = note
      }
      return nil
    }
  }

  /// A bell or a title from the engine: something happened, not what. It
  /// never downgrades a state the occupant reported.
  public mutating func noteActivity(in id: TerminalSession.ID, isSeen: Bool) {
    let key = Key.session(id)
    guard entries[key]?.state == nil, !isSeen else { return }
    update(key) { $0.state = .done }
  }

  /// The shell's foreground command returned: the one engine signal that
  /// outranks a report. A non-zero exit is Failed, and covers a Done.
  public mutating func noteCommandFinished(
    in id: TerminalSession.ID, exitCode: Int32?, isSeen: Bool
  ) {
    let key = Key.session(id)
    let finished = SessionState.finished(exitCode: exitCode)
    // An agent killed with a worker out sends no SubagentStop; the command
    // it was has returned, so nothing is out and nothing is owed.
    update(key) { $0.settleTurn() }
    switch entries[key]?.state {
    case .running, .attention, nil:
      update(key) {
        $0.state = isSeen && finished.clearsWhenSeen ? nil : finished
        $0.pid = nil
      }
    case .done:
      if finished == .error { update(key) { $0.state = .error } }
    case .error, .idle:
      break
    }
  }

  /// The shown tab and the selected worktree have been seen. Done goes;
  /// the rest stay until something other than a look deals with them.
  public mutating func markSeen(sessions: [TerminalSession.ID], worktree: Worktree.ID?) {
    for key in keys(sessions, worktree) where entries[key]?.state?.clearsWhenSeen == true {
      update(key) { $0.state = nil }
    }
  }

  /// Whether `markSeen` would clear anything. Its caller copies the whole
  /// value to mutate it, and the engine reports focus on every click.
  func hasAnythingToSee(sessions: [TerminalSession.ID], worktree: Worktree.ID?) -> Bool {
    keys(sessions, worktree).contains { entries[$0]?.state?.clearsWhenSeen == true }
  }

  private func keys(_ sessions: [TerminalSession.ID], _ worktree: Worktree.ID?) -> [Key] {
    sessions.map(Key.session) + (worktree.map { [Key.worktree($0)] } ?? [])
  }

  /// The state and what it claimed go; the stamp and the note are left for
  /// `stampChanges`, which reads the transition.
  public mutating func clear(_ key: Key) {
    update(key) {
      $0.state = nil
      $0.pid = nil
      $0.settleTurn()
    }
  }

  /// The user's own clear, for a Working dot whose agent is long gone.
  public mutating func clear(sessions: [TerminalSession.ID], worktree: Worktree.ID?) {
    for id in sessions { clear(.session(id)) }
    if let worktree { clear(.worktree(worktree)) }
  }

  /// Keeps the keys a subset of what exists: live shells and known
  /// worktrees. Done for a dead shell is nothing to look at.
  public mutating func retain(sessions: Set<TerminalSession.ID>, worktrees: Set<Worktree.ID>) {
    entries = entries.filter { entry in
      switch entry.key {
      case .session(let id): sessions.contains(id)
      case .worktree(let id): worktrees.contains(id)
      }
    }
  }

  /// The process a state was about has gone. Working and Waiting were claims
  /// about it and go; Done and Failed are about the user and stay.
  public mutating func processGone(_ pid: Int32) {
    for (key, entry) in entries where entry.pid == pid {
      update(key) {
        if $0.state?.isFinished != true { $0.state = nil }
        $0.pid = nil
        // Its workers went with it, so nothing is owed and nothing is out.
        $0.settleTurn()
      }
    }
  }

  /// Records when each key's state changed, once per mutation, and stamps a
  /// worker's start. A key that did not move keeps its time.
  public mutating func stampChanges(against previous: SessionStates, at now: Date) {
    for key in Set(entries.keys).union(previous.entries.keys)
    where entries[key]?.state != previous.entries[key]?.state {
      update(key) {
        $0.since = now
        if $0.state == nil { $0.note = nil }
      }
    }
    for (key, entry) in entries where entry.workers.contains(where: { $0.since == nil }) {
      update(key) {
        for index in $0.workers.indices where $0.workers[index].since == nil {
          $0.workers[index].since = now
        }
      }
    }
  }

  /// The ends a shell's exit stands for, one per key it is out under.
  func endings(ofShell pid: Int32) -> [(key: Key, report: SubagentReport)] {
    entries.flatMap { key, entry in
      entry.workers.filter { $0.pid == pid }.map {
        (key: key, report: SubagentReport(id: $0.id, phase: .ended))
      }
    }
  }

  /// The agents' own pids and their background shells'.
  var trackedPIDs: Set<Int32> {
    Set(entries.values.flatMap { [$0.pid] + $0.workers.map(\.pid) }.compactMap { $0 })
  }

  public func state(ofSessions ids: [TerminalSession.ID]) -> SessionState? {
    SessionState.mostUrgent(ids.compactMap { self[.session($0)] })
  }

  public func state(ofWorktree id: Worktree.ID, sessions: [TerminalSession.ID]) -> SessionState? {
    var candidates = sessions.compactMap { self[.session($0)] }
    if let own = self[.worktree(id)] { candidates.append(own) }
    return SessionState.mostUrgent(candidates)
  }

  /// Shells whose agent reported Working, for the quit guard.
  var workingSessionCount: Int {
    entries.filter { key, entry in
      if case .session = key { return entry.state == .running }
      return false
    }.count
  }

  /// Nothing showing and nothing out. A stamp and a note outlive the state
  /// they were about, so neither counts; a roster does.
  public var isEmpty: Bool {
    !entries.values.contains { $0.state != nil || !$0.workers.isEmpty }
  }
}
