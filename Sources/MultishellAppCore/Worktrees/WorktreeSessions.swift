import MultishellCore

/// Every session id by worktree, gathered once per sidebar render: a row
/// then costs a lookup where it cost a scan of every session.
public struct WorktreeSessions: Sendable {
  private let ids: [Worktree.ID: [TerminalSession.ID]]

  public init(_ sessions: [TerminalSession]) {
    var ids: [Worktree.ID: [TerminalSession.ID]] = [:]
    for session in sessions { ids[session.worktreeID, default: []].append(session.id) }
    self.ids = ids
  }

  public subscript(worktree: Worktree.ID) -> [TerminalSession.ID] { ids[worktree] ?? [] }
}
