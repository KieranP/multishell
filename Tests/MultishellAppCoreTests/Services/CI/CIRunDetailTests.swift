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
    #expect(detail(.passed, runWasFinished: true).stillDescribes(run, readAt: longAgo))
    #expect(!detail(.running, runWasFinished: false).stillDescribes(run, readAt: longAgo))
  }

  @Test func aRunStillGoingIsReadAgainOnceAMinuteThoughOneJobHasFailed() {
    let failing = CIRun.sample(status: .failed, isFinished: false)
    #expect(detail(.failed, runWasFinished: false).stillDescribes(failing, readAt: .now))
    #expect(!detail(.failed, runWasFinished: false).stillDescribes(failing, readAt: longAgo))
  }

  @Test func detailReadWhileTheRunWentIsReadOnceMoreWhenItEnds() {
    let ended = CIRun.sample(status: .failed, isFinished: true)
    #expect(!detail(.failed, runWasFinished: false).stillDescribes(ended, readAt: .now))
  }

  @Test func twoCopiesOfARunThatDisagreeDoNotReadItEveryTimeEachAsks() {
    let rowsCopy = CIRun.sample(status: .running)
    let readByTheHistorysCopy = detail(.passed, runWasFinished: true)
    #expect(readByTheHistorysCopy.stillDescribes(rowsCopy, readAt: .now))
  }
}
