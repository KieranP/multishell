import AppKit
import Testing

@testable import MultishellAppUI

@Suite @MainActor
struct FileTabFocusTargetViewTests {
  @Test func aClickTakesTheKeyboardAndSaysSoOnce() throws {
    let view = FileTabFocusTargetView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
    var focusCount = 0
    view.onFocus = { focusCount += 1 }
    let window = OffscreenWindow.holding(view)
    let click = try mouseEvent(.leftMouseDown, at: NSPoint(x: 50, y: 50), in: window)

    view.mouseDown(with: click)

    #expect(window.firstResponder === view)
    #expect(focusCount == 1)
  }
}
