import MultishellServices

/// A branch the project's newest pull requests left out, asked about alone,
/// and the upstream tip it was asked at.
struct BranchPullRequestLookup: Equatable {
  let upstreamTip: String?
  let pullRequests: [PullRequest]

  /// Asked again once the branch is pushed to, or while one of its own is open:
  /// its review, checks and merge move with no push. See services/reads.md.
  func stillAnswers(upstreamTip tip: String?, headedIn repositories: [RemoteRepository]) -> Bool {
    tip == upstreamTip
      && !pullRequests.contains { pullRequest in
        !pullRequest.state.isSettled && pullRequest.isHeadedWhereKnown(inAnyOf: repositories)
      }
  }
}
