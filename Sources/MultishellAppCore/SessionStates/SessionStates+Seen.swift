import MultishellCore

extension SessionStates {
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
}
