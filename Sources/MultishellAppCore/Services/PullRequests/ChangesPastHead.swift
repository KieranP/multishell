/// Whether a branch's tip has a change of its own its merged pull request's
/// head lacks: a scan asks it once, each services read again as remotes move.
struct ChangesPastHead: Hashable, Sendable {
  let head: String
  let tip: String
  /// The branch's own remote branch, `origin/feat`: commits only it holds are
  /// still the branch's, where another remote branch's came with a sync.
  let ownRemoteBranch: String
  /// The worktree's local branch, left out of the other branches likewise.
  let ownBranch: String
}
