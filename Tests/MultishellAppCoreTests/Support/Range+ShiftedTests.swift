import Testing

@testable import MultishellAppCore

@Suite
struct RangeShiftedTests {
  @Test func aRangeShiftsBothBoundsBySignedOffset() {
    #expect((3..<7).shifted(by: 10) == 13..<17)
    #expect((13..<17).shifted(by: -10) == 3..<7)
  }
}
