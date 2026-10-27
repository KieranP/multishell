import MultishellCore

/// Create Pull Request's question before it pushes: a branch the remote has
/// not got, or commits it has not, would leave the pull request without them.
public struct PendingBranchPublish: Identifiable, Equatable, Sendable {
  let worktree: Worktree
  let branch: String
  let remote: String
  /// Its name on the remote: the upstream's where it has one, else its own.
  let remoteBranch: String
  /// Commits ahead of the upstream; `nil` where the remote lacks the branch.
  let unpushedCommits: Int?
  /// The remote has a branch of that name this one does not track.
  var remoteHasBranch = false

  public var id: Worktree.ID { worktree.id }
}
