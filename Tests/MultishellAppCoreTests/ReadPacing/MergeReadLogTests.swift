import Foundation
import Testing

@testable import MultishellAppCore

@Suite
struct MergeReadLogTests {
  @Test func aRoundTakesReadsUntilTheirLastCostsFillTheBudget() {
    var log = MergeReadLog()
    log.budget = .seconds(2)
    log.remember(["a": .seconds(1), "b": .seconds(1), "c": .seconds(1)])

    #expect(log.admit(["a", "b", "c"], sharingRound: false).count == 2)
  }

  @Test func everyWorktreeNeverReadIsAdmittedWhateverTheBudget() {
    var log = MergeReadLog()
    log.budget = .zero

    #expect(log.admit(["a", "b", "c"], sharingRound: false) == ["a", "b", "c"])
  }

  @Test func theProjectsOfOneRoundShareTheBudget() {
    var log = MergeReadLog()
    log.budget = .seconds(2)
    log.remember(["a": .seconds(1), "b": .seconds(1), "c": .seconds(1), "d": .seconds(1)])

    #expect(log.admit(["a", "b"], sharingRound: true).count == 2)
    #expect(log.admit(["c", "d"], sharingRound: true).count == 1, "each project still gets one")
  }

  @Test func oneReadCostingMoreThanTheBudgetStillRuns() {
    var log = MergeReadLog()
    log.budget = .seconds(1)
    log.remember(["slow": .seconds(5)])

    #expect(log.admit(["slow"], sharingRound: false) == ["slow"])
  }

  @Test func aWorktreeNeverReadGoesFirstThenTheLongestSinceAnswered() {
    var log = MergeReadLog()
    log.budget = .zero
    log.remember(["old": .seconds(1)])
    log.remember(["new": .seconds(1)])

    #expect(log.admit(["new", "old", "unread"], sharingRound: false) == ["unread"])
    #expect(log.admit(["new", "old"], sharingRound: false) == ["old"])
  }
}
