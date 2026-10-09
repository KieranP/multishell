import Testing

@testable import MultishellAppCore

@Suite
struct DebugRangeWordingTests {
  @Test func eachRangeIsNamedForItsSpanAndTheAxisStartsThatLongAgo() {
    #expect(DebugRange.allCases.map(\.title) == ["1 min", "5 min", "15 min"])
    #expect(DebugRange.allCases.map(\.agoTitle) == ["1 min ago", "5 min ago", "15 min ago"])
  }
}
