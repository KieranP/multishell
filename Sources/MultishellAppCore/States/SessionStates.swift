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

  public private(set) var states: [Key: SessionState] = [:]
  /// The process behind a Working or Waiting state, when the report said.
  public private(set) var pids: [Key: Int32] = [:]
  /// When each key's state last changed, so the board can say how long a pane
  /// has been in its column. Handed in, never read from a clock.
  public private(set) var since: [Key: Date] = [:]
  /// What the last report about each key said beyond its state.
  public private(set) var notes: [Key: SessionNote] = [:]
  /// Background workers an agent still has out, by key. Only an agent that
  /// reports them has an entry; see docs/design/agents.md.
  private var background: [Key: Int] = [:]
  /// Keys whose agent said it had finished while workers were still out. The
  /// Done is owed, and the last worker to end pays it.
  private var owedDone: Set<Key> = []

  public init() {}

  public subscript(key: Key) -> SessionState? { states[key] }

  // MARK: - Sources

  /// A report over the channel; `isSeen` means the user is looking at it.
  /// Returns what it meant, which `settling` may move, and `nil` where it
  /// was only bookkeeping: a counting tick is not news to announce.
  @discardableResult
  public mutating func report(
    _ state: SessionState, pid: Int32?, message: String? = nil, duration: Double? = nil,
    subagents: Int = 0, for key: Key, isSeen: Bool
  ) -> SessionState? {
    let settled = settling(state, subagents: subagents, for: key)
    // A counting tick that kept the Waiting already there. It carries no
    // message of its own, and the prompt's is what the card should say.
    let isBookkeeping = settled == .attention && state == .running
    let state = settled
    switch state {
    case .idle:
      clear(key)
    case .done, .error:
      states[key] = isSeen && state.clearsWhenSeen ? nil : state
      pids[key] = nil
    case .running, .attention:
      states[key] = state
      if let pid { pids[key] = pid }
    }
    // Only where a state survived the report: a Done about a tab the user is
    // looking at leaves nothing to say something about.
    if states[key] != nil, !isBookkeeping {
      notes[key] = SessionNote(state: state, message: message, duration: duration)
    }
    return isBookkeeping ? nil : state
  }

  /// What a report means once background workers are counted. An agent
  /// reporting none keeps the state it gave; see docs/design/agents.md.
  private mutating func settling(
    _ state: SessionState, subagents: Int, for key: Key
  ) -> SessionState {
    guard subagents == 0 else {
      let count = max(0, (background[key] ?? 0) + subagents)
      background[key] = count == 0 ? nil : count
      // The last one out pays the Done its agent reported while they ran.
      if count == 0, owedDone.remove(key) != nil { return .done }
      // Counting events carry `.running` for want of anything to say, so a
      // tick is not news: only the source clears a Waiting.
      if state == .running, states[key] == .attention { return .attention }
      return state
    }
    switch state {
    case .done where background[key] != nil:
      // The main loop stopping is not the turn finishing: a banner here fires
      // at the wrong moment, and the next worker's report undoes the dot.
      owedDone.insert(key)
      return .running
    case .idle, .error:
      // A session ending, or failing, settles the whole turn.
      background[key] = nil
      owedDone.remove(key)
      return state
    default:
      return state
    }
  }

  /// A bell or a title from the engine: something happened, not what. It
  /// never downgrades a state the occupant reported.
  public mutating func noteActivity(in id: TerminalSession.ID, isSeen: Bool) {
    let key = Key.session(id)
    guard states[key] == nil, !isSeen else { return }
    states[key] = .done
  }

  /// The shell's foreground command returned: the one engine signal that
  /// outranks a report. A non-zero exit is Failed, and covers a Done.
  public mutating func noteCommandFinished(
    in id: TerminalSession.ID, exitCode: Int32?, isSeen: Bool
  ) {
    let key = Key.session(id)
    let finished = SessionState.finished(exitCode: exitCode)
    switch states[key] {
    case .running, .attention, nil:
      states[key] = isSeen && finished.clearsWhenSeen ? nil : finished
      pids[key] = nil
    case .done:
      if finished == .error { states[key] = .error }
    case .error, .idle:
      break
    }
  }

  // MARK: - Clearing

  /// The shown tab and the selected worktree have been seen. Done goes;
  /// the rest stay until something other than a look deals with them.
  public mutating func markSeen(sessions: [TerminalSession.ID], worktree: Worktree.ID?) {
    var keys = sessions.map(Key.session)
    if let worktree { keys.append(.worktree(worktree)) }
    for key in keys where states[key]?.clearsWhenSeen == true {
      states[key] = nil
    }
  }

  public mutating func clear(_ key: Key) {
    states[key] = nil
    pids[key] = nil
    background[key] = nil
    owedDone.remove(key)
  }

  /// The user's own clear, for a Working dot whose agent is long gone.
  public mutating func clear(sessions: [TerminalSession.ID], worktree: Worktree.ID?) {
    for id in sessions { clear(.session(id)) }
    if let worktree { clear(.worktree(worktree)) }
  }

  /// Keeps the keys a subset of what exists: live shells and known
  /// worktrees. Done for a dead shell is nothing to look at.
  public mutating func retain(sessions: Set<TerminalSession.ID>, worktrees: Set<Worktree.ID>) {
    let keep: (Key) -> Bool = { key in
      switch key {
      case .session(let id): sessions.contains(id)
      case .worktree(let id): worktrees.contains(id)
      }
    }
    states = states.filter { keep($0.key) }
    pids = pids.filter { keep($0.key) }
    since = since.filter { keep($0.key) }
    notes = notes.filter { keep($0.key) }
    background = background.filter { keep($0.key) }
    owedDone = owedDone.filter(keep)
  }

  /// The process a state was about has gone. Working and Waiting were claims
  /// about it and go; Done and Failed are about the user and stay.
  public mutating func processGone(_ pid: Int32) {
    for (key, tracked) in pids where tracked == pid {
      if states[key]?.isFinished != true { states[key] = nil }
      pids[key] = nil
      // Its workers went with it, so nothing is owed and nothing is out.
      background[key] = nil
      owedDone.remove(key)
    }
  }

  // MARK: - Time in state

  /// Records when each key's state changed, once per mutation. A key that did
  /// not move keeps its time, so repeated Working reports do not reset it.
  public mutating func stampChanges(against previous: SessionStates, at now: Date) {
    for key in Set(states.keys).union(previous.states.keys)
    where states[key] != previous.states[key] {
      since[key] = now
      if states[key] == nil { notes[key] = nil }
    }
  }

  // MARK: - Queries

  public var trackedPIDs: Set<Int32> { Set(pids.values) }

  public func state(ofSessions ids: [TerminalSession.ID]) -> SessionState? {
    SessionState.mostUrgent(ids.compactMap { states[.session($0)] })
  }

  public func state(ofWorktree id: Worktree.ID, sessions: [TerminalSession.ID]) -> SessionState? {
    var candidates = sessions.compactMap { states[.session($0)] }
    if let own = states[.worktree(id)] { candidates.append(own) }
    return SessionState.mostUrgent(candidates)
  }

  /// Shells whose agent reported Working, for the quit guard.
  public var workingSessionCount: Int {
    states.filter { key, state in
      if case .session = key { return state == .running }
      return false
    }.count
  }

  public var isEmpty: Bool { states.isEmpty }
}
