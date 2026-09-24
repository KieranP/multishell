import Foundation
import Testing

@testable import MultishellAppCore

/// What paces a worktree's `git status`, on the plain value the model keeps
/// the readings in. The rule itself is `StatusPollPaceTests`.
@Suite
struct StatusReadLogTests {
  private let a = "/trees/a"
  private let b = "/trees/b"

  @Test func aWorktreeNeverReadIsDue() {
    let log = StatusReadLog()
    #expect(log.isEmpty)
    #expect(log.isDue(a, at: .now))
  }

  @Test func aSlowReadHoldsTheNextOneBackAndAQuickOneDoesNot() {
    var log = StatusReadLog()
    log.remember([a: .seconds(2), b: .milliseconds(10)])
    let justAfter = ContinuousClock.now.advanced(by: .seconds(1))
    #expect(!log.isDue(a, at: justAfter), "two seconds costs twenty before the next")
    #expect(log.isDue(b, at: justAfter), "ten milliseconds is inside the interval")
    #expect(log.isDue(a, at: ContinuousClock.now.advanced(by: .seconds(21))))
  }

  @Test func anUnpacedLogAsksAgainWhateverTheReadCost() {
    var log = StatusReadLog()
    log.pace = .unpaced
    log.remember([a: .seconds(30)])
    #expect(log.isDue(a, at: .now))
  }

  @Test func aWorktreeThatWentPacesNothing() {
    var log = StatusReadLog()
    log.remember([a: .seconds(2), b: .seconds(2)])
    log.forget([a])
    #expect(log.isDue(a, at: .now), "its path is free for the next worktree there")
    #expect(!log.isDue(b, at: .now))
    #expect(!log.isEmpty)
  }

  /// A read in flight when the indicator changed used to count what the badge
  /// no longer means, and its cost paced the read that does.
  @Test func aReadInFlightWhenTheIndicatorChangedNoLongerCounts() {
    var log = StatusReadLog()
    let stale = log.begin([a])

    log.remember([a: .seconds(2)])
    log.invalidate()
    #expect(!log.isReading(a), "the read that replaces it may start")
    #expect(log.isEmpty, "and every worktree is due again")
    #expect(log.isDue(a, at: .now))
    let counted = log.finish(stale)
    #expect(!counted)
  }

  @Test func aRowIsHeldUntilTheReadThatTookItLastFinishes() {
    var log = StatusReadLog()
    let first = log.begin([a, b])
    #expect(log.isReading(a) && log.isReading(b))

    let second = log.begin([a])
    _ = log.finish(first)
    #expect(log.isReading(a), "the later read still holds it")
    #expect(!log.isReading(b))

    _ = log.finish(second)
    #expect(!log.isReading(a))
  }

  @Test func aStaleReadFinishingLetsGoOfNothingTheNewOneHolds() {
    var log = StatusReadLog()
    let stale = log.begin([a])
    log.invalidate()
    let fresh = log.begin([a])

    let staleCounted = log.finish(stale)
    #expect(!staleCounted)
    #expect(log.isReading(a))
    let freshCounted = log.finish(fresh)
    #expect(freshCounted)
  }
}
