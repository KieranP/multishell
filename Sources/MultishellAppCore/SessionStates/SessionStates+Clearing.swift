import MultishellCore

extension SessionStates {
  /// The state and what it claimed go; the stamp and the note are left for
  /// `stampChanges`, which reads the transition.
  mutating func clear(_ key: Key) {
    update(key) { stored in
      stored.state = nil
      stored.pid = nil
      stored.settleTurn()
    }
  }

  /// The user's own clear, for a Working dot whose agent is long gone. A hold
  /// goes too; see agents/program-status.md.
  mutating func clear(sessions: [TerminalSession.ID], worktree: Worktree.ID?) {
    for id in sessions {
      clear(.session(id))
      update(.session(id)) { $0.forgetProgramHold() }
    }
    if let worktree { clear(.worktree(worktree)) }
  }

  mutating func noteProcessGone(_ pid: Int32) {
    for (key, entry) in entries {
      if entry.pid == pid || entry.programRecords.pid == pid {
        dropProcessClaims(on: key)
      } else if entry.agentReportedByHooks?.pid == pid {
        // Its hooks' agent gone with no hold on its pid: only the name goes.
        update(key) { $0.agentReportedByHooks = nil }
      }
    }
  }

  /// Working and Waiting were claims about a process now gone, and go with
  /// its workers and its program's hold; Done and Failed stay.
  mutating func dropProcessClaims(on key: Key) {
    endProgramHold(on: key)
    update(key) { stored in
      if stored.state?.isFinished != true { stored.state = nil }
      stored.pid = nil
      stored.settleTurn()
    }
    ownConversationIDs[key] = nil
  }
}
