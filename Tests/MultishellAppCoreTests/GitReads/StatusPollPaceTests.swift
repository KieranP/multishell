import Testing

@testable import MultishellAppCore

@Suite
struct StatusPollPaceTests {
  @Test func aSlowStatusIsNotAskedAgainUntilTenTimesItsCostHasPassed() {
    let pace = StatusPollPace.standard
    let now = ContinuousClock.now
    #expect(pace.isDue(lastRead: nil, duration: nil, at: now))
    #expect(pace.isDue(lastRead: now - .seconds(1), duration: .milliseconds(50), at: now))
    #expect(!pace.isDue(lastRead: now - .seconds(10), duration: .seconds(3), at: now))
    #expect(pace.isDue(lastRead: now - .seconds(30), duration: .seconds(3), at: now))
    #expect(StatusPollPace.unpaced.isDue(lastRead: now, duration: .seconds(30), at: now))
  }
}
