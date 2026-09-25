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

  subscript(key: Key) -> SessionState? { entries[key]?.state }

  func since(_ key: Key) -> Date? { entries[key]?.since }
  func note(_ key: Key) -> SessionNote? { entries[key]?.note }

  /// The workers out under one key, oldest first.
  func subagents(_ key: Key) -> [Subagent] { entries[key]?.subagents ?? [] }

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
    var subagent = subagent
    var startsTurn = startsTurn
    // A worker's end names the conversation it ran under: the pane's own, where
    // a pane that heard the worker first took the worker for its own.
    if let conversationID, let ending = subagent, ending.phase == .ended,
      ownConversationIDs[key] == ending.id
    {
      ownConversationIDs[key] = conversationID
      update(key) { $0.forgetSubagent(conversationID) }
    }
    if let conversationID, subagent == nil,
      let worker = worker(inConversation: conversationID, reporting: state, for: key)
    {
      subagent = worker
      startsTurn = false
    }
    // A prompt starts a turn, so whatever the last one left out is gone: an
    // agent interrupted, Codex aside, fires no hook and its workers send no stop.
    if startsTurn { update(key) { $0.settleTurn() } }
    if state == .done, subagent == nil {
      update(key) {
        $0.keepShells(backgroundShells)
        $0.stopResumes = resumesAfterWorkers
      }
    }
    guard let state = meaning(of: state, subagent: subagent, for: key) else { return nil }
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
    update(key) { $0.workingIsShellCommand = fromShell && $0.state == .running }
    // Only where a state survived the report: a Done about a tab the user is
    // looking at leaves nothing to say something about.
    if entries[key]?.state != nil {
      update(key) { $0.note = SessionNote(state: state, message: message, duration: duration) }
    }
    return state
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
      update(key) { $0.forgetSubagent(conversation) }
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
    for (key, entry) in entries where entry.subagents.contains(where: { $0.since == nil }) {
      update(key) {
        for index in $0.subagents.indices where $0.subagents[index].since == nil {
          $0.subagents[index].since = now
        }
      }
    }
  }

  /// The ends a shell's exit stands for, one per key it is out under.
  func endings(ofShell pid: Int32) -> [(key: Key, report: SubagentReport)] {
    entries.flatMap { key, entry in
      entry.subagents.filter { $0.pid == pid }.map {
        (key: key, report: SubagentReport(id: $0.id, phase: .ended))
      }
    }
  }

  /// The agents' own pids and their background shells'.
  var trackedPIDs: Set<Int32> {
    Set(entries.values.flatMap { [$0.pid] + $0.subagents.map(\.pid) }.compactMap { $0 })
  }

  func state(ofSessions ids: [TerminalSession.ID]) -> SessionState? {
    SessionState.mostUrgent(ids.compactMap { self[.session($0)] })
  }

  func state(ofWorktree id: Worktree.ID, sessions: [TerminalSession.ID]) -> SessionState? {
    var candidates = sessions.compactMap { self[.session($0)] }
    if let own = self[.worktree(id)] { candidates.append(own) }
    return SessionState.mostUrgent(candidates)
  }

  /// Shells whose agent reported Working, for the quit guard.
  var workingAgentCount: Int {
    entries.filter { key, entry in
      if case .session = key { return entry.state == .running }
      return false
    }.count
  }

  /// Nothing showing and nothing out. A stamp and a note outlive the state
  /// they were about, so neither counts; a roster does.
  var isEmpty: Bool {
    !entries.values.contains { $0.state != nil || !$0.subagents.isEmpty }
  }
}
