import Testing

@testable import MultishellAppCore

@Suite
struct DebugStripPositionTests {
  @Test func eachBoundaryIsMeasuredUpFromTheChartsBottom() {
    let point = DebugStripPoint(tops: [0.25, 0.5, 0.75])
    let position = DebugStripPosition(x: 3, point: point, height: 40)

    #expect(position.y(.baseline) == 40)
    #expect(position.y(.top(ofSeries: 0)) == 30)
    #expect(position.y(.top(ofSeries: 1)) == 20)
    #expect(position.y(.total) == 10)
  }

  @Test func aSeriesPastThePointsOwnReadsAsItsTotal() {
    let position = DebugStripPosition(x: 0, point: DebugStripPoint(tops: [0.5]), height: 40)
    #expect(position.y(.top(ofSeries: 3)) == 20)
  }
}
