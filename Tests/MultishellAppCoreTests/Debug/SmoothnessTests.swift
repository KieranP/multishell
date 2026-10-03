import Testing

@testable import MultishellAppCore

@Suite
struct SmoothnessTests {
  @Test func aSecondIsJudgedByItsLongestFrame() {
    #expect(Smoothness.of(longestFrame: nil) == .smooth)
    #expect(Smoothness.of(longestFrame: .milliseconds(17)) == .smooth)
    #expect(Smoothness.of(longestFrame: .milliseconds(50)) == .hitched)
    #expect(Smoothness.of(longestFrame: .milliseconds(100)) == .stalled)
  }
}
