import Testing

@testable import MultishellAppCore

@Suite
struct ArrayHasRangeMeetingTests {
  private static let ranges = [2..<5, 9..<12]

  @Test func aRangeOverlappingOneOfTheRangesMeetsIt() {
    #expect(Self.ranges.hasRange(meeting: 4..<7))
    #expect(Self.ranges.hasRange(meeting: 0..<20))
  }

  @Test func aRangeOnlyTouchingOrBetweenTheRangesMeetsNone() {
    #expect(!Self.ranges.hasRange(meeting: 5..<9))
    #expect(!Self.ranges.hasRange(meeting: 0..<2))
    #expect(!Self.ranges.hasRange(meeting: 12..<14))
  }

  @Test func anEmptyRangeMeetsOneOnlyStrictlyInsideIt() {
    #expect(Self.ranges.hasRange(meeting: 3..<3))
    #expect(!Self.ranges.hasRange(meeting: 2..<2))
  }
}
