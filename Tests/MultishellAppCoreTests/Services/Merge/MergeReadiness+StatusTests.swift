import Testing

@testable import MultishellAppCore
@testable import MultishellServices

@Suite
struct MergeReadinessStatusTests {
  @Test func onlyAReviewOrAPendingCheckLeftReadsAsWaiting() {
    #expect(
      MergeReadiness(.sample(review: .required), checks: [.sample(status: .running)]).status
        == .running
    )
    #expect(
      MergeReadiness(.sample(review: .required), checks: [.sample(status: .failed)]).status
        == .failed
    )
  }

  @Test func aDraftWithNothingElseWrongIsOnHoldNotFailed() {
    #expect(
      MergeReadiness(.sample(state: .draft), checks: [.sample(status: .passed)]).status == .onHold
    )
  }

  @Test func aReviewAloneIsOnHoldAndItsRowWaitsOnAPersonToo() {
    let readiness = MergeReadiness(.sample(review: .required), checks: [.sample(status: .passed)])
    #expect(readiness.status == .onHold)
    #expect(readiness.requirements.first { $0.kind == .review }?.status == .onHold)
  }

  @Test func aDraftWithAPendingCheckStillReadsAsRunning() {
    #expect(
      MergeReadiness(.sample(state: .draft), checks: [.sample(status: .running)]).status == .running
    )
  }

  @Test func aReadyPullRequestReadsAsPassedAndAClosedOneAsCancelled() {
    #expect(MergeReadiness(.sample(), checks: [.sample(status: .passed)]).status == .passed)
    #expect(MergeReadiness(.sample(state: .closed), checks: []).status == .cancelled)
  }
}
