import Testing

@testable import MultishellAppCore

@Suite
struct DebugChartPositionTests {
  @Test func eachBoundaryIsMeasuredUpFromTheChartsBottom() {
    let point = DebugChartPoint(tops: [0.25, 0.5, 0.75])
    let position = DebugChartPosition(x: 3, point: point, height: 40)

    #expect(position.y(.baseline) == 40)
    #expect(position.y(.top(ofSeries: 0)) == 30)
    #expect(position.y(.top(ofSeries: 1)) == 20)
    #expect(position.y(.total) == 10)
  }

  @Test func aSeriesPastThePointsOwnReadsAsItsTotal() {
    let position = DebugChartPosition(x: 0, point: DebugChartPoint(tops: [0.5]), height: 40)
    #expect(position.y(.top(ofSeries: 3)) == 20)
  }
}
