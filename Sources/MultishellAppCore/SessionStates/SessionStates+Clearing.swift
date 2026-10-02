import MultishellCore

extension SessionStates {
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
}
