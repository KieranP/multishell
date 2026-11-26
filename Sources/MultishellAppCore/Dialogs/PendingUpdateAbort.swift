import MultishellCore

/// Abort Merge or Abort Rebase's question while an agent works there: it may be
/// resolving the conflicts the abort would throw away.
public struct PendingUpdateAbort: Identifiable, Equatable, Sendable {
  let worktree: Worktree
  /// What the title calls it: the branch a stopped rebase lists the worktree without.
  let worktreeName: String
  let method: UpdateMethod
  /// The stop asked about, which a later one of the same kind does not match.
  let mark: String?
  let workingAgentName: String

  public var id: Worktree.ID { worktree.id }
}
