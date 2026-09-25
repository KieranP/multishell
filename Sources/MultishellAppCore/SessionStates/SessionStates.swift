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

  private(set) var entries: [Key: Entry] = [:]
  /// The id of each pane's own conversation, from an agent that runs a
  /// worker as one of its own. Apart from `entries`, which go on a clear.
  private var ownConversationIDs: [Key: String] = [:]

  /// An entry with nothing left in it goes, so `isEmpty` and `==` read true.
  mutating func update(_ key: Key, _ change: (inout Entry) -> Void) {
    var entry = entries[key] ?? Entry()
    change(&entry)
    entries[key] = entry.isEmpty ? nil : entry
  }

  /// A report over the channel, `isSeen` the user looking at it. Returns what
  /// it meant once the roster is kept, `nil` for a bookkeeping tick.
  @discardableResult
  mutating func report(
    _ state: SessionState, pid: Int32?, message: String? = nil, duration: Double? = nil,
    subagent: SubagentReport? = nil, startsTurn: Bool = false, startsSession: Bool = false,
    backgroundShells: [Int32] = [], fromShell: Bool = false,
    resumesAfterWorkers: Bool = false, conversationID: String? = nil, for key: Key, isSeen: Bool
  ) -> SessionState? {
    // Copilot's prompt mode starts its session after the first prompt. Before
    // the conversation is read, or a dropped start re-points the pane's own.
    if startsSession, subagent == nil, entries[key]?.workingIsShellCommand != true,
      [.running, .attention].contains(entries[key]?.state)
    {
      return nil
    }
    let (subagent, isAnotherConversation) = workerAfterReading(
      conversation: conversationID, named: subagent, reporting: state, for: key)
    // A prompt starts a turn, so whatever the last one left out is gone: an
    // agent interrupted, Codex aside, fires no hook and its workers send no stop.
    if startsTurn, !isAnotherConversation { update(key) { $0.settleTurn() } }
    if state == .done, subagent == nil {
      update(key) {
        $0.roster.keepShells(backgroundShells)
        $0.stopResumes = resumesAfterWorkers
      }
    }
    guard let state = meaning(of: state, subagent: subagent, for: key) else { return nil }
    switch state {
    case .idle:
      clear(key)
    case .done, .failed:
      landFinished(state, on: key, isSeen: isSeen)
    case .running, .attention:
      update(key) {
        $0.state = state
        if let pid { $0.pid = pid }
      }
    }
    update(key) { $0.workingIsShellCommand = fromShell && $0.state == .running }
    noteIfStanding(SessionNote(state: state, message: message, duration: duration), on: key)
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
  mutating func noteIfStanding(_ note: SessionNote, on key: Key) {
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
    in id: TerminalSession.ID, exitCode: Int32?, isSeen: Bool
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

  /// The shown tab and the selected worktree have been seen. Done goes;
  /// the rest stay until something other than a look deals with them.
  mutating func markSeen(sessions: [TerminalSession.ID], worktree: Worktree.ID?) {
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
  mutating func clear(_ key: Key) {
    update(key) {
      $0.state = nil
      $0.pid = nil
      $0.settleTurn()
    }
  }

  /// The user's own clear, for a Working dot whose agent is long gone.
  mutating func clear(sessions: [TerminalSession.ID], worktree: Worktree.ID?) {
    for id in sessions { clear(.session(id)) }
    if let worktree { clear(.worktree(worktree)) }
  }

  /// Keeps the keys a subset of what exists: live shells and known
  /// worktrees. Done for a dead shell is nothing to look at.
  mutating func retain(sessions: Set<TerminalSession.ID>, worktrees: Set<Worktree.ID>) {
    func exists(_ key: Key) -> Bool {
      switch key {
      case .session(let id): sessions.contains(id)
      case .worktree(let id): worktrees.contains(id)
      }
    }
    entries = entries.filter { exists($0.key) }
    ownConversationIDs = ownConversationIDs.filter { exists($0.key) }
  }

  /// The process a state was about has gone. Working and Waiting were claims
  /// about it and go; Done and Failed are about the user and stay.
  mutating func processGone(_ pid: Int32) {
    for (key, entry) in entries where entry.pid == pid {
      update(key) {
        if $0.state?.isFinished != true { $0.state = nil }
        $0.pid = nil
        // Its workers went with it, so nothing is owed and nothing is out.
        $0.settleTurn()
      }
      ownConversationIDs[key] = nil
    }
  }

  /// Records when each key's state changed, once per mutation, and stamps a
  /// worker's start. A state put back with its own stamp keeps it.
  mutating func stampChanges(against previous: SessionStates, at now: Date) {
    for key in Set(entries.keys).union(previous.entries.keys)
    where entries[key]?.state != previous.entries[key]?.state
      && (entries[key]?.since == nil || entries[key]?.since == previous.entries[key]?.since)
    {
      update(key) {
        $0.since = now
        if $0.state == nil { $0.note = nil }
      }
    }
    for (key, entry) in entries where entry.roster.hasUnstampedStarts {
      update(key) { $0.roster.stampStarts(at: now) }
    }
  }
}
