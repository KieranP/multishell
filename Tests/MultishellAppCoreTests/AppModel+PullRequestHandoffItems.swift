import MultishellCore
import MultishellServices

@testable import MultishellAppCore

extension AppModel {
  /// The shown pull request's failing checks, then its unresolved threads, as the
  /// PR page lists them.
  func pullRequestHandoffItems(
    of pullRequest: PullRequest,
    in worktree: Worktree,
  ) -> [PullRequestHandoffItem] {
    PullRequestHandoffItem.items(
      checks: mergeReadiness(of: pullRequest, in: worktree).checks,
      headCommit: pullRequest.headCommit,
      threads: unresolvedThreads(of: pullRequest, in: worktree),
    )
  }
}
