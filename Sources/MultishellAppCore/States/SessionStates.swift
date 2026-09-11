import Foundation
import MultishellCore

/// What each live terminal, and each worktree reported on from outside a
/// tab, is doing right now, with the rules for who clears what.
///
/// Runtime only, beside the live sessions; a prompt must not save or
/// re-render the workspace. Done is about the user and clears when the tab
/// has been seen. Working and Waiting are about the process: they stay while
/// the user looks, and clear when the source reports again, the process is
/// gone, or the user clears them by hand. Failed takes the look half of that
/// and not the process half: a failure is something to act on and a glance
/// is not acting, but it has outlived the thing that failed, so only a new
/// report or the user's own clear takes it. Pure, so the rules are tested
/// without a view or an engine.
///
/// Seen is one notion throughout, and the same one a banner is raised
/// against: the pane on screen and the app frontmost. On screen alone is not
/// it, a pane being the shown one while the user is in another app entirely,
/// and it is `NotificationPolicy` that would then disagree, saying they had
/// not seen the very thing this had just cleared.
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
  /// When each key's state last changed, going back to nothing included, so
  /// the board can say how long a pane has been in the column it is in. The
  /// one time in this value, and it is handed in rather than read from a
  /// clock; see `stampChanges`.
  public private(set) var since: [Key: Date] = [:]
  /// What the last report about each key said beyond its state.
  public private(set) var notes: [Key: SessionNote] = [:]

  public init() {}

  public subscript(key: Key) -> SessionState? { states[key] }

  // MARK: - Sources

  /// A report over the channel. `isSeen` means the user is looking at the
  /// tab, or at the worktree for a worktree-level report, with the app in
  /// front of them.
  public mutating func report(
    _ state: SessionState, pid: Int32?, message: String? = nil, duration: Double? = nil,
    for key: Key, isSeen: Bool
  ) {
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
    if states[key] != nil {
      notes[key] = SessionNote(state: state, message: message, duration: duration)
    }
  }

  /// A bell or a title from the engine: something happened, not what. It
  /// never downgrades a state the occupant reported; an agent retitles the
  /// tab on every step while it works.
  public mutating func noteActivity(in id: TerminalSession.ID, isSeen: Bool) {
    let key = Key.session(id)
    guard states[key] == nil, !isSeen else { return }
    states[key] = .done
  }

  /// The shell's foreground command returned, so whatever was Working or
  /// Waiting in it has exited. The one engine signal that outranks a report.
  /// A non-zero exit is Failed, and a failure is not covered by an earlier
  /// Done the user has not seen yet.
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
  /// Failed stays, along with Working and Waiting, until something other
  /// than a look deals with it.
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
  }

  /// The process a state was about has left the table. Working and Waiting
  /// were claims about it and go; Done and Failed are about the user and
  /// stay.
  public mutating func processGone(_ pid: Int32) {
    for (key, tracked) in pids where tracked == pid {
      if states[key]?.isFinished != true { states[key] = nil }
      pids[key] = nil
    }
  }

  // MARK: - Time in state

  /// Records when each key's state changed, measured against what this value
  /// held before the change. Called once per mutation by the model, which is
  /// the only place a clock is read; a key whose state did not move keeps the
  /// time it has, so an agent reporting Working on every tool call does not
  /// keep resetting how long it has been working.
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
