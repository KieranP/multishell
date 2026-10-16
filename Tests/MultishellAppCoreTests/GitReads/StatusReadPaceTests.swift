import Testing

@testable import MultishellAppCore

@Suite
struct StatusReadPaceTests {
  @Test func aSlowStatusIsNotAskedAgainUntilTenTimesItsCostHasPassed() {
    let pace = StatusReadPace.standard
    let now = ContinuousClock.now
    #expect(pace.isDue(lastRead: nil, duration: nil, at: now))
    #expect(pace.isDue(lastRead: now - .seconds(1), duration: .milliseconds(50), at: now))
    #expect(!pace.isDue(lastRead: now - .seconds(10), duration: .seconds(3), at: now))
    #expect(pace.isDue(lastRead: now - .seconds(30), duration: .seconds(3), at: now))
    #expect(StatusReadPace.unpaced.isDue(lastRead: now, duration: .seconds(30), at: now))
  }

  @Test func aQuickStatusIsNotAskedAgainWithinTheMinimumGap() {
    let pace = StatusReadPace.standard
    let now = ContinuousClock.now
    #expect(!pace.isDue(lastRead: now - .milliseconds(400), duration: .milliseconds(20), at: now))
    #expect(
      pace.nextDue(lastRead: now, duration: .milliseconds(20)) == now + pace.minimumGap
    )
  }

  @Test func aSlowStatusIsNextDueAtTenTimesItsCost() {
    let now = ContinuousClock.now
    #expect(
      StatusReadPace.standard.nextDue(lastRead: now, duration: .seconds(3)) == now + .seconds(30)
    )
    #expect(StatusReadPace.standard.nextDue(lastRead: nil, duration: nil) == nil)
  }
}
