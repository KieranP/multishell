import Testing

@testable import MultishellAppCore
@testable import MultishellServices

@Suite
struct BranchRunLookupTests {
  @Test func aSettledAnswerStandsUntilTheBranchIsPushedTo() {
    let lookup = BranchRunLookup(upstreamTip: "a", run: .sample(status: .passed))
    #expect(lookup.stillAnswers(upstreamTip: "a"))
    #expect(!lookup.stillAnswers(upstreamTip: "b"))
  }

  @Test func aBranchThatNeverRanIsNotAskedAgainUntilPushedTo() {
    #expect(BranchRunLookup(upstreamTip: "a", run: nil).stillAnswers(upstreamTip: "a"))
  }

  @Test func aRunUnderWayIsAskedAgainEveryRound() {
    #expect(
      !BranchRunLookup(upstreamTip: "a", run: .sample(status: .running)).stillAnswers(
        upstreamTip: "a"
      )
    )
  }

  @Test func aRunWithAFailedJobThatHasNotEndedIsAskedAgain() {
    let failing = CIRun.sample(status: .failed, isFinished: false)
    #expect(!BranchRunLookup(upstreamTip: "a", run: failing).stillAnswers(upstreamTip: "a"))
  }

  @Test func aRunOnHoldIsAskedAgainSoItsApprovalIsSeen() {
    let onHold = CIRun.sample(status: .onHold)
    #expect(!BranchRunLookup(upstreamTip: "a", run: onHold).stillAnswers(upstreamTip: "a"))
  }
}
