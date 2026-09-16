import Testing

@testable import MultishellAppCore

@Suite
struct StatusPollPaceTests {
  @Test func aSlowStatusIsNotAskedAgainUntilTenTimesItsCostHasPassed() {
    let pace = StatusPollPace.standard
    let now = ContinuousClock.now
    #expect(pace.isDue(lastRead: nil, took: nil, at: now))
    #expect(pace.isDue(lastRead: now - .seconds(1), took: .milliseconds(50), at: now))
    #expect(!pace.isDue(lastRead: now - .seconds(10), took: .seconds(3), at: now))
    #expect(pace.isDue(lastRead: now - .seconds(30), took: .seconds(3), at: now))
    #expect(StatusPollPace.unpaced.isDue(lastRead: now, took: .seconds(30), at: now))
  }
}
