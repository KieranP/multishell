import CoreGraphics
import Testing

@testable import MultishellAppUI

@Suite
struct WindowResizeTests {
  private let screen = CGRect(x: 0, y: 0, width: 1_512, height: 944)
  private let minimum = CGSize(width: 720, height: 420)

  @Test func aSizeTheScreenHoldsKeepsTheTopEdge() {
    let window = CGRect(x: 100, y: 200, width: 800, height: 600)

    let resized = WindowResize.frame(
      resizing: window,
      to: CGSize(width: 1_000, height: 700),
      minimum: minimum,
      within: screen,
    )

    #expect(resized == CGRect(x: 100, y: 100, width: 1_000, height: 700))
  }

  @Test func aSizeBelowTheLeastIsRaisedToIt() {
    let window = CGRect(x: 100, y: 200, width: 800, height: 600)

    let resized = WindowResize.frame(
      resizing: window,
      to: CGSize(width: 300, height: 200),
      minimum: minimum,
      within: screen,
    )

    #expect(resized.size == minimum)
    #expect(resized.maxY == window.maxY)
  }

  @Test func aSizeLargerThanTheScreenIsCutToItAndKeptOnIt() {
    let window = CGRect(x: 600, y: 200, width: 800, height: 600)

    let resized = WindowResize.frame(
      resizing: window,
      to: CGSize(width: 4_000, height: 3_000),
      minimum: minimum,
      within: screen,
    )

    #expect(resized == screen)
  }

  @Test func aWiderWindowNearTheRightEdgeMovesLeftRatherThanRunOff() {
    let window = CGRect(x: 1_000, y: 200, width: 800, height: 600)

    let resized = WindowResize.frame(
      resizing: window,
      to: CGSize(width: 1_200, height: 600),
      minimum: minimum,
      within: screen,
    )

    #expect(resized == CGRect(x: 312, y: 200, width: 1_200, height: 600))
  }
}
