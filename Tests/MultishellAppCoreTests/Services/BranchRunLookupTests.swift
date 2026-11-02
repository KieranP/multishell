import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellServices

@Suite
struct BranchRunLookupTests {
  private let tip = "9f2bcef611aa"

  private func lookup(_ run: CIRun?, askedSince: Date = .now) -> BranchRunLookup {
    BranchRunLookup(upstreamTip: tip, run: run, tipAskedSince: askedSince)
  }

  @Test func aSettledRunOfTheTipStandsUntilTheBranchIsPushedTo() {
    let settled = lookup(.sample(commit: "9f2bcef", status: .passed))
    #expect(settled.stillAnswers(upstreamTip: tip, now: .now))
    #expect(!settled.stillAnswers(upstreamTip: "b", now: .now))
  }

  @Test func aSettledRunOfAnEarlierCommitIsAskedAgainWhileTheTipsRunMayStillBeComing() {
    let earlier = lookup(.sample(commit: "0000000", status: .failed))
    #expect(!earlier.stillAnswers(upstreamTip: tip, now: .now))
  }

  @Test func aSettledRunOfAnEarlierCommitStandsOnceTheTipHasHadTimeToRun() {
    let earlier = lookup(.sample(commit: "0000000", status: .failed), askedSince: .distantPast)
    #expect(earlier.stillAnswers(upstreamTip: tip, now: .now))
  }

  @Test func aBranchWithNoRunYetIsAskedAgainWhileItsFirstRunMayStillBeComing() {
    #expect(!lookup(nil).stillAnswers(upstreamTip: tip, now: .now))
  }

  @Test func aBranchThatNeverRanStandsOnceItsFirstRunHasHadTimeToCome() {
    #expect(lookup(nil, askedSince: .distantPast).stillAnswers(upstreamTip: tip, now: .now))
  }

  @Test func aRunUnderWayIsAskedAgainEveryRound() {
    let running = lookup(.sample(commit: "9f2bcef", status: .running), askedSince: .distantPast)
    #expect(!running.stillAnswers(upstreamTip: tip, now: .now))
  }

  @Test func aRunWithAFailedJobThatHasNotEndedIsAskedAgain() {
    let failing = CIRun.sample(commit: "9f2bcef", status: .failed, isFinished: false)
    #expect(!lookup(failing, askedSince: .distantPast).stillAnswers(upstreamTip: tip, now: .now))
  }

  @Test func aRunOnHoldIsAskedAgainSoItsApprovalIsSeen() {
    let onHold = CIRun.sample(commit: "9f2bcef", status: .onHold)
    #expect(!lookup(onHold, askedSince: .distantPast).stillAnswers(upstreamTip: tip, now: .now))
  }

  @Test func aRunOfUnknownStatusIsAskedAgainEveryRound() {
    let unknown = CIRun.sample(commit: "9f2bcef", status: .unknown)
    #expect(!lookup(unknown, askedSince: .distantPast).stillAnswers(upstreamTip: tip, now: .now))
  }
}
