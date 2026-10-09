import Testing

@testable import MultishellAppCore

@Suite
struct DebugStripPositionTests {
  @Test func eachBoundaryIsMeasuredUpFromTheStripsBottom() {
    let point = DebugStripPoint(app: 0.25, appWithTerminals: 0.5, total: 0.75)
    let position = DebugStripPosition(x: 3, point: point, height: 40)

    #expect(position.y(.baseline) == 40)
    #expect(position.y(.app) == 30)
    #expect(position.y(.appWithTerminals) == 20)
    #expect(position.y(.total) == 10)
  }
}
