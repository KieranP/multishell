import Foundation

@testable import MultishellServices

extension PullRequest {
  static func sample(
    number: Int = 44,
    state: PullRequestState = .open,
    review: PullRequestReview = .notRequired,
    blocker: PullRequestBlocker? = nil,
    hasConflictAnswer: Bool = true,
    autoMergesWhenReady: Bool = false,
    isReadyToMerge: Bool = false,
    headBranch: String = "feat",
    headCommit: String = "tip",
    owner: String = "me",
    baseBranch: String = "main",
    updatedAt: Date = Date(timeIntervalSince1970: 1_800_000_000),
  ) -> Self {
    PullRequest(
      number: number,
      title: "Pull request \(number)",
      url: URL(string: "https://github.com/me/demo/pull/\(number)")!,
      state: state,
      review: review,
      blocker: blocker,
      hasConflictAnswer: hasConflictAnswer,
      autoMergesWhenReady: autoMergesWhenReady,
      isReadyToMerge: isReadyToMerge,
      headBranch: headBranch,
      headCommit: headCommit,
      headRepository: RemoteRepository(owner: owner, name: "demo"),
      baseBranch: baseBranch,
      updatedAt: updatedAt,
    )
  }
}
