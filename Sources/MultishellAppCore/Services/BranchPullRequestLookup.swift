import MultishellServices

/// A branch the project's newest pull requests left out, asked about alone,
/// and the upstream tip it was asked at.
struct BranchPullRequestLookup: Equatable {
  let upstreamTip: String?
  let pullRequests: [PullRequest]

  /// Asked again once the branch is pushed to, or while one is open: its
  /// review, checks and merge move with no push. See services.md.
  func stillAnswers(upstreamTip tip: String?) -> Bool {
    tip == upstreamTip && !pullRequests.contains { $0.state == .open || $0.state == .draft }
  }
}
