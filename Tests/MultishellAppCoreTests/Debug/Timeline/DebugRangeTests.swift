import Testing

@testable import MultishellAppCore

@Suite
struct DebugRangeTests {
  @Test func everyRangeHoldsWholeSlotsAndAStripDrawsAtMost180() {
    for range in DebugRange.allCases {
      #expect(range.sampleCount.isMultiple(of: range.secondsPerSlot), "\(range)")
      #expect(range.slotCount <= 180, "\(range)")
    }
  }
}
