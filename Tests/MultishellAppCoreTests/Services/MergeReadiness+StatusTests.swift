import Testing

@testable import MultishellAppCore
@testable import MultishellServices

@Suite
struct MergeReadinessStatusTests {
  private func check(_ status: CIRunStatus) -> PullRequestCheck {
    PullRequestCheck(name: "build", workflow: "CI", status: status, isRequired: true, link: nil)
  }

  @Test func onlyAReviewOrAPendingCheckLeftReadsAsWaiting() {
    #expect(
      MergeReadiness(.sample(review: .required), checks: [check(.running)]).status == .running
    )
    #expect(
      MergeReadiness(.sample(review: .required), checks: [check(.failed)]).status == .failed
    )
  }

  @Test func aDraftWithNothingElseWrongReadsAsWaitingNotFailed() {
    #expect(MergeReadiness(.sample(state: .draft), checks: [check(.passed)]).status == .running)
  }

  @Test func aReadyPullRequestReadsAsPassedAndAClosedOneAsCancelled() {
    #expect(MergeReadiness(.sample(), checks: [check(.passed)]).status == .passed)
    #expect(MergeReadiness(.sample(state: .closed), checks: []).status == .cancelled)
  }
}
