@testable import MultishellAppCore
@testable import MultishellServices

extension MergePath {
  static func sample(
    _ pullRequest: PullRequest,
    checks: [PullRequestCheck]?,
    isMergeTaken: Bool = false,
    isOutgrown: Bool = false,
    checksReadProblem: String? = nil,
  ) -> Self {
    MergePath(
      pullRequest,
      readiness: MergeReadiness(pullRequest, checks: checks),
      isMergeTaken: isMergeTaken,
      isOutgrown: isOutgrown,
      checksReadProblem: checksReadProblem,
    )
  }
}
