import CoreGraphics
import Testing

@testable import MultishellAppUI

@Suite @MainActor
struct ViewScreenshotTests {
  @Test func aSurfaceIsPlacedAtItsOwnSizeFromTheTopLeftAsTheLayerShowsItNotStretched() {
    let pane = CGRect(x: 10, y: 20, width: 300, height: 200)

    let resizing = ViewScreenshot.place(
      surfaceOfPixels: CGSize(width: 800, height: 600),
      scale: 2,
      in: pane,
    )
    let settled = ViewScreenshot.place(
      surfaceOfPixels: CGSize(width: 600, height: 400),
      scale: 2,
      in: pane,
    )

    #expect(resizing == CGRect(x: 10, y: -80, width: 400, height: 300))
    #expect(settled == pane)
  }
}
