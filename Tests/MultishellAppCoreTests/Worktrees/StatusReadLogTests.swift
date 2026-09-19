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

  /// The bug this guards: a read in flight when the indicator changed
  /// counted what the badge no longer means, so its cost must not pace the
  /// read that does.
  @Test func aReadInFlightWhenTheIndicatorChangedNoLongerCounts() {
    var log = StatusReadLog()
    let generation = log.currentGeneration()
    #expect(log.stillCounts(generation))

    log.remember([a: .seconds(2)])
    log.invalidate()
    #expect(!log.stillCounts(generation))
    #expect(log.isEmpty, "and every worktree is due again")
    #expect(log.isDue(a, at: .now))
  }
}
