/// What a worktree's actions menu offers for its pull request.
public enum PullRequestMenuItem: Equatable, Sendable {
  /// Create Pull Request…, disabled while it pushes the branch.
  case create(isPublishing: Bool)
  case open(number: Int)
}
