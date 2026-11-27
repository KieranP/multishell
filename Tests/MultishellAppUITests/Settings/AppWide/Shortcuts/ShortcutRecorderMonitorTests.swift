import AppKit
import Testing

@testable import MultishellAppUI

@Suite @MainActor
struct ShortcutRecorderMonitorTests {
  @Test func aKeyCountsAsTypedForTheRecorderOnlyInItsOwnWindow() throws {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 10, height: 10),
      styleMask: [],
      backing: .buffered,
      defer: false,
    )
    let number = window.windowNumber
    try #require(number > 0)

    #expect(
      ShortcutRecorderMonitor.isTyped(
        try keyEvent(.keyDown, "\u{7F}", keyCode: 51, windowNumber: number),
        inWindowNumbered: number,
      )
    )
    #expect(
      !ShortcutRecorderMonitor.isTyped(
        try keyEvent(.keyDown, "\u{7F}", keyCode: 51, windowNumber: number + 1),
        inWindowNumbered: number,
      ),
      "a Delete typed in a pane must not clear the command",
    )
  }
}
