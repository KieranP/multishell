import MultishellGitKit

/// Where a worktree's branch stands past its working tree: whether it landed,
/// and its pull request and CI run, as its row draws and reads them.
public struct BranchStanding: Equatable, Sendable {
  public let mergeState: WorktreeMergeState
  public let services: WorktreeServices

  /// A pull request replaces the merged badge, and work only here hides it;
  /// see `WorktreeMergeState.showsBadge`.
  public func showsMergedBadge(with status: WorktreeStatus?) -> Bool {
    services.shownPullRequest == nil && mergeState.showsBadge(with: status)
  }
}
