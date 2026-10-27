/// What the reviews of an open pull request add up to. Raw values are what
/// `worktrees show` prints.
public enum PullRequestReview: String, Hashable, Sendable {
  case approved
  case changesRequested = "changes-requested"
  /// The base branch needs no review, or none has been asked for.
  case notRequired = "not-required"
  /// The base branch's rules want a review it does not have yet.
  case required
}
