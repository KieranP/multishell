import MultishellCore
import MultishellServices

extension PullRequest {
  /// Its state, then what its reviews add up to, what holds it back and
  /// whether it merges by itself: "Approved · Conflicts with main".
  public var stateText: String {
    var parts: [String]
    switch state {
    case .closed: parts = [t("pull-request.closed")]
    case .draft: parts = [t("pull-request.draft")]
    case .merged: parts = [t("pull-request.merged", baseBranch)]
    case .open: parts = [Self.reviewText(of: review)]
    }
    guard state == .open || state == .draft else {
      return parts.joined(separator: " · ")
    }
    if let blocker, !Self.isExplainedByReview(blocker, review: review) {
      parts.append(Self.blockerText(of: blocker, base: baseBranch))
    }
    // The words for the glyph's green, which changes asked for never draw.
    if isReadyToMerge, review != .changesRequested { parts.append(t("pull-request.ready")) }
    if autoMergesWhenReady { parts.append(t("pull-request.auto-merge")) }
    return parts.joined(separator: " · ")
  }

  private static func blockerText(of blocker: PullRequestBlocker, base: String) -> String {
    switch blocker {
    case .behindBase: t("pull-request.behind-base", base)
    case .blocked: t("pull-request.blocked", base)
    case .conflicts: t("pull-request.conflicts", base)
    }
  }

  /// A review still wanted is reason enough for GitHub's BLOCKED, so the
  /// review's words say it.
  private static func isExplainedByReview(
    _ blocker: PullRequestBlocker,
    review: PullRequestReview,
  ) -> Bool {
    blocker == .blocked && [.required, .changesRequested].contains(review)
  }

  private static func reviewText(of review: PullRequestReview) -> String {
    switch review {
    case .approved: t("pull-request.approved")
    case .changesRequested: t("pull-request.changes-requested")
    case .notRequired: t("pull-request.open")
    case .required: t("pull-request.review-required")
    }
  }
}
