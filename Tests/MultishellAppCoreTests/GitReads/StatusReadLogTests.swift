import Testing

@testable import MultishellAppCore

/// What paces a worktree's `git status`, on the plain value the model keeps
/// the readings in. The rule itself is `StatusPollPaceTests`.
@Suite
struct StatusReadLogTests {
  private let firstTree = "/trees/a"
  private let secondTree = "/trees/b"

  @Test func aWorktreeNeverReadIsDue() {
    let log = StatusReadLog()
    #expect(log.hasNoReadings)
    #expect(log.isDue(firstTree, at: .now))
  }

  @Test func aSlowReadHoldsTheNextOneBackAndAQuickOneDoesNot() {
    var log = StatusReadLog()
    log.remember([firstTree: .seconds(2), secondTree: .milliseconds(10)])
    let justAfter = ContinuousClock.now.advanced(by: .seconds(1))
    #expect(!log.isDue(firstTree, at: justAfter), "two seconds costs twenty before the next")
    #expect(log.isDue(secondTree, at: justAfter), "ten milliseconds is inside the interval")
    #expect(log.isDue(firstTree, at: ContinuousClock.now.advanced(by: .seconds(21))))
  }

  @Test func anUnpacedLogAsksAgainWhateverTheReadCost() {
    var log = StatusReadLog()
    log.pace = .unpaced
    log.remember([firstTree: .seconds(30)])
    #expect(log.isDue(firstTree, at: .now))
  }

  @Test func aWorktreeThatWentPacesNothing() {
    var log = StatusReadLog()
    log.remember([firstTree: .seconds(2), secondTree: .seconds(2)])
    log.forget([firstTree])
    #expect(log.isDue(firstTree, at: .now), "its path is free for the next worktree there")
    #expect(!log.isDue(secondTree, at: .now))
    #expect(!log.hasNoReadings)
  }

  /// A read in flight when the indicator changed used to count what the badge
  /// no longer means, and its cost paced the read that does.
  @Test func aReadInFlightWhenTheIndicatorChangedNoLongerCounts() {
    var log = StatusReadLog()
    let stale = log.begin([firstTree])

    log.remember([firstTree: .seconds(2)])
    log.invalidate()
    #expect(!log.isReading(firstTree), "the read that replaces it may start")
    #expect(log.hasNoReadings, "and every worktree is due again")
    #expect(log.isDue(firstTree, at: .now))
    let counted = log.finish(stale)
    #expect(!counted)
  }

  @Test func aRowIsHeldUntilTheReadThatTookItLastFinishes() {
    var log = StatusReadLog()
    let first = log.begin([firstTree, secondTree])
    #expect(log.isReading(firstTree) && log.isReading(secondTree))

    let second = log.begin([firstTree])
    _ = log.finish(first)
    #expect(log.isReading(firstTree), "the later read still holds it")
    #expect(!log.isReading(secondTree))

    _ = log.finish(second)
    #expect(!log.isReading(firstTree))
  }

  @Test func aStaleReadFinishingLetsGoOfNothingTheNewOneHolds() {
    var log = StatusReadLog()
    let stale = log.begin([firstTree])
    log.invalidate()
    let fresh = log.begin([firstTree])

    let staleCounted = log.finish(stale)
    #expect(!staleCounted)
    #expect(log.isReading(firstTree))
    let freshCounted = log.finish(fresh)
    #expect(freshCounted)
  }
}
