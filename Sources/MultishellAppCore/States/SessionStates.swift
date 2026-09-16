import Foundation
import MultishellCore

/// What each live terminal is doing, and who clears what. Runtime only; see
/// docs/design/agents.md.
public struct SessionStates: Equatable, Sendable {
  public enum Key: Hashable, Sendable {
    case session(TerminalSession.ID)
    /// A report that named only a directory: a hook fired from another
    /// terminal in that worktree.
    case worktree(Worktree.ID)
  }

  /// Everything known about one key, so a prune is one dictionary operation.
  /// `since` and `note` outlive a state that went nil: `stampChanges` owns them.
  struct Entry: Equatable, Sendable {
    var state: SessionState?
    /// The process behind a Working or Waiting state, when the report said.
    var pid: Int32?
    /// When the state last changed. Handed in, never read from a clock.
    var since: Date?
    /// What the last report said beyond its state.
    var note: SessionNote?
    /// Background workers the agent still has out; see docs/design/agents.md.
    var background = 0
    /// The agent said it had finished while workers were still out, so the
    /// Done is owed, and the last worker to end pays it.
    var owesDone = false

    var isEmpty: Bool {
      state == nil && pid == nil && since == nil && note == nil && background == 0 && !owesDone
    }
  }

  private var entries: [Key: Entry] = [:]

  public init() {}

  public subscript(key: Key) -> SessionState? { entries[key]?.state }

  public func since(_ key: Key) -> Date? { entries[key]?.since }
  public func note(_ key: Key) -> SessionNote? { entries[key]?.note }

  public var states: [Key: SessionState] { entries.compactMapValues(\.state) }
  public var pids: [Key: Int32] { entries.compactMapValues(\.pid) }
  public var since: [Key: Date] { entries.compactMapValues(\.since) }
  public var notes: [Key: SessionNote] { entries.compactMapValues(\.note) }

  /// An entry with nothing left in it goes, so `isEmpty` and `==` read true.
  private mutating func update(_ key: Key, _ change: (inout Entry) -> Void) {
    var entry = entries[key] ?? Entry()
    change(&entry)
    entries[key] = entry.isEmpty ? nil : entry
  }

  /// A report over the channel; `isSeen` means the user is looking at it.
  /// Returns what it meant, which `settling` may move, and `nil` where it
  /// was only bookkeeping: a counting tick is not news to announce.
  @discardableResult
  public mutating func report(
    _ state: SessionState, pid: Int32?, message: String? = nil, duration: Double? = nil,
    subagents: Int = 0, for key: Key, isSeen: Bool
  ) -> SessionState? {
    guard let state = settling(state, subagents: subagents, for: key) else { return nil }
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

  /// What a report means once background workers are counted, `nil` for a
  /// tick that moves nothing. See docs/design/agents.md.
  private mutating func settling(
    _ state: SessionState, subagents: Int, for key: Key
  ) -> SessionState? {
    guard subagents == 0 else {
      let count = max(0, (entries[key]?.background ?? 0) + subagents)
      // The last one out pays the Done its agent reported while they ran.
      var paysDone = false
      update(key) {
        $0.background = count
        if count == 0, $0.owesDone {
          $0.owesDone = false
          paysDone = true
        }
      }
      if paysDone { return .done }
      // Counting events carry `.running` for want of anything to say, so a
      // tick is not news: it carries no message, and what is there stands.
      if state == .running, let current = entries[key]?.state, current != .running { return nil }
      return state
    }
    switch state {
    case .done where (entries[key]?.background ?? 0) > 0:
      // The main loop stopping is not the turn finishing: a banner here fires
      // at the wrong moment, and the next worker's report undoes the dot.
      update(key) { $0.owesDone = true }
      return .running
    case .idle, .error:
      // A session ending, or failing, settles the whole turn.
      update(key) {
        $0.background = 0
        $0.owesDone = false
      }
      return state
    default:
      return state
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
    var keys = sessions.map(Key.session)
    if let worktree { keys.append(.worktree(worktree)) }
    for key in keys where entries[key]?.state?.clearsWhenSeen == true {
      update(key) { $0.state = nil }
    }
  }

  /// The state and what it claimed go; the stamp and the note are left for
  /// `stampChanges`, which reads the transition.
  public mutating func clear(_ key: Key) {
    update(key) {
      $0.state = nil
      $0.pid = nil
      $0.background = 0
      $0.owesDone = false
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
        $0.background = 0
        $0.owesDone = false
      }
    }
  }

  /// Records when each key's state changed, once per mutation. A key that did
  /// not move keeps its time, so repeated Working reports do not reset it.
  public mutating func stampChanges(against previous: SessionStates, at now: Date) {
    for key in Set(entries.keys).union(previous.entries.keys)
    where entries[key]?.state != previous.entries[key]?.state {
      update(key) {
        $0.since = now
        if $0.state == nil { $0.note = nil }
      }
    }
  }

  public var trackedPIDs: Set<Int32> { Set(entries.values.compactMap(\.pid)) }

  public func state(ofSessions ids: [TerminalSession.ID]) -> SessionState? {
    SessionState.mostUrgent(ids.compactMap { self[.session($0)] })
  }

  public func state(ofWorktree id: Worktree.ID, sessions: [TerminalSession.ID]) -> SessionState? {
    var candidates = sessions.compactMap { self[.session($0)] }
    if let own = self[.worktree(id)] { candidates.append(own) }
    return SessionState.mostUrgent(candidates)
  }

  /// Shells whose agent reported Working, for the quit guard.
  public var workingSessionCount: Int {
    entries.filter { key, entry in
      if case .session = key { return entry.state == .running }
      return false
    }.count
  }

  public var isEmpty: Bool { !entries.values.contains { $0.state != nil } }
}
