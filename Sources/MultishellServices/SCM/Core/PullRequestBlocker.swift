/// What keeps an open pull request from merging, where the host says; the row
/// draws only a conflict. Raw values are what `worktrees show` prints.
public enum PullRequestBlocker: String, Decodable, Hashable, Sendable {
  case behindBase = "behind-base"
  /// GitHub's BLOCKED, which names no cause: a review, a check or a rule.
  case blocked
  case conflicts
}
