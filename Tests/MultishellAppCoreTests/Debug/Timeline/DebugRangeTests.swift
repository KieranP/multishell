import Testing

@testable import MultishellAppCore

@Suite
struct DebugRangeTests {
  @Test func everyRangeHoldsWholeSlotsAndAStripDrawsAtMost180() {
    for range in DebugRange.allCases {
      #expect(range.sampleCount % range.secondsPerSlot == 0, "\(range)")
      #expect(range.slotCount <= 180, "\(range)")
    }
  }
}
