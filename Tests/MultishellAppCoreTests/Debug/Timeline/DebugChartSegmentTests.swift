import Testing

@testable import MultishellAppCore

@Suite
struct DebugChartSegmentTests {
  @Test func pointsAreSplitWhereASlotHasNoReading() {
    let point = DebugChartPoint(tops: [0.2, 0.3, 0.5])
    let segments = DebugChartSegment.segments(in: [nil, point, point, nil, nil, point])

    #expect(segments.map(\.firstIndex) == [1, 5])
    #expect(segments.map(\.points.count) == [2, 1])
    #expect(DebugChartSegment.segments(in: [nil, nil]).isEmpty)
  }

  @Test func eachPointSitsAtTheMiddleOfItsSlot() {
    let point = DebugChartPoint(tops: [0.2, 0.3, 0.5])
    let segment = DebugChartSegment(firstIndex: 3, points: [point, point])
    #expect(segment.slotPositions.map(\.slot) == [3.5, 4.5])
  }

  @Test func aLonePointSpansItsWholeSlotSoItHasWidthToDraw() {
    let point = DebugChartPoint(tops: [0.2, 0.3, 0.5])
    let segment = DebugChartSegment(firstIndex: 3, points: [point])
    #expect(segment.slotPositions.map(\.slot) == [3, 4])
    #expect(segment.slotPositions.map(\.point) == [point, point])
  }
}
