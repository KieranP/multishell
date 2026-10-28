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

  @Test func aDraftWithNothingElseWrongIsOnHoldNotFailed() {
    #expect(MergeReadiness(.sample(state: .draft), checks: [check(.passed)]).status == .onHold)
  }

  @Test func aReviewAloneIsOnHoldAndItsRowWaitsOnAPersonToo() {
    let readiness = MergeReadiness(.sample(review: .required), checks: [check(.passed)])
    #expect(readiness.status == .onHold)
    #expect(readiness.requirements.first { $0.kind == .review }?.status == .onHold)
  }

  @Test func aDraftWithAPendingCheckStillReadsAsRunning() {
    #expect(MergeReadiness(.sample(state: .draft), checks: [check(.running)]).status == .running)
  }

  @Test func aReadyPullRequestReadsAsPassedAndAClosedOneAsCancelled() {
    #expect(MergeReadiness(.sample(), checks: [check(.passed)]).status == .passed)
    #expect(MergeReadiness(.sample(state: .closed), checks: []).status == .cancelled)
  }
}
