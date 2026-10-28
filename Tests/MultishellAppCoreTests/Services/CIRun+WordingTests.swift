import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellServices

@Suite
struct CIRunWordingTests {
  @Test func aRunIsHeadedByItsSubjectElseItsShortCommit() {
    let named = CIRun(
      id: "a",
      branch: "feat",
      commit: "9f2bcef611",
      subject: "Fix the build",
      status: .passed,
      isFinished: true,
      createdAt: nil,
    )
    let unnamed = CIRun(
      id: "b",
      branch: "feat",
      commit: "9f2bcef611",
      subject: nil,
      status: .passed,
      isFinished: true,
      createdAt: nil,
    )
    #expect(named.headline == "Fix the build")
    #expect(unnamed.headline == "9f2bcef")
  }

  @Test func aRunSaysNothingOfTheLocalTipWhereItIsUnknown() {
    let run = CIRun.sample(commit: "9f2bcef611")
    #expect(run.startText(localTip: nil, now: .now) == "")
    #expect(run.startText(localTip: "other0000", now: .now) == "not the local tip")
  }

  @Test func whenARunStartedIsToldAgainstTheTimeGiven() {
    let started = Date(timeIntervalSince1970: 1_700_000_000)
    let run = CIRun.sample(commit: "9f2bcef611", createdAt: started)
    let later = started.addingTimeInterval(4 * 60)
    #expect(run.startText(localTip: nil, now: later) == "Started 4 minutes ago")
  }

  @Test func aRunReadAfterTheClockLastTickedIsNeverSaidToStartInTheFuture() {
    let started = Date(timeIntervalSince1970: 1_700_000_000)
    let run = CIRun.sample(commit: "9f2bcef611", createdAt: started)
    let staleClock = started.addingTimeInterval(-10)
    #expect(!run.startText(localTip: nil, now: staleClock).contains("in "))
  }
}
