import Testing

@testable import MultishellAppCore

@Suite
struct DebugStripSegmentTests {
  @Test func pointsAreSplitWhereASlotHasNoReading() {
    let point = DebugStripPoint(app: 0.2, appWithTerminals: 0.3, total: 0.5)
    let segments = DebugStripSegment.segments(in: [nil, point, point, nil, nil, point])

    #expect(segments.map(\.firstIndex) == [1, 5])
    #expect(segments.map(\.points.count) == [2, 1])
    #expect(DebugStripSegment.segments(in: [nil, nil]).isEmpty)
  }

  @Test func eachPointSitsAtTheMiddleOfItsSlot() {
    let point = DebugStripPoint(app: 0.2, appWithTerminals: 0.3, total: 0.5)
    let segment = DebugStripSegment(firstIndex: 3, points: [point, point])
    #expect(segment.slotPositions.map(\.slot) == [3.5, 4.5])
  }

  @Test func aLonePointSpansItsWholeSlotSoItHasWidthToDraw() {
    let point = DebugStripPoint(app: 0.2, appWithTerminals: 0.3, total: 0.5)
    let segment = DebugStripSegment(firstIndex: 3, points: [point])
    #expect(segment.slotPositions.map(\.slot) == [3, 4])
    #expect(segment.slotPositions.map(\.point) == [point, point])
  }
}
