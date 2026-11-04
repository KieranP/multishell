import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellServices

@Suite
struct CIRunDetailTests {
  private let longAgo = Date(timeIntervalSince1970: 0)

  private func detail(_ status: CIRunStatus, runWasFinished: Bool) -> CIRunDetail<[CIWorkflow]> {
    CIRunDetail(value: [], runStatus: status, runWasFinished: runWasFinished)
  }

  @Test func anEndedRunsDetailStillDescribesItWhileItsStatusHolds() {
    let run = CIRun.sample(status: .passed)
    #expect(detail(.passed, runWasFinished: true).stillDescribe(run, readAt: longAgo))
    #expect(!detail(.running, runWasFinished: false).stillDescribe(run, readAt: longAgo))
  }

  @Test func aRunStillGoingIsReadAgainOnceAMinuteThoughOneJobHasFailed() {
    let failing = CIRun.sample(status: .failed, isFinished: false)
    #expect(detail(.failed, runWasFinished: false).stillDescribe(failing, readAt: .now))
    #expect(!detail(.failed, runWasFinished: false).stillDescribe(failing, readAt: longAgo))
  }

  @Test func detailReadWhileTheRunWentIsReadOnceMoreWhenItEnds() {
    let ended = CIRun.sample(status: .failed, isFinished: true)
    #expect(!detail(.failed, runWasFinished: false).stillDescribe(ended, readAt: .now))
  }

  @Test func twoCopiesOfARunThatDisagreeDoNotReadItEveryTimeEachAsks() {
    let rowsCopy = CIRun.sample(status: .running)
    let readByTheHistorysCopy = detail(.passed, runWasFinished: true)
    #expect(readByTheHistorysCopy.stillDescribe(rowsCopy, readAt: .now))
  }
}
