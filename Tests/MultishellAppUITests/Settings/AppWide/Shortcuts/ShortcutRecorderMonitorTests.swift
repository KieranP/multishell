import AppKit
import Testing

@testable import MultishellAppUI

@Suite @MainActor
struct ShortcutRecorderMonitorTests {
  private func keyDown(inWindowNumbered number: Int) throws -> NSEvent {
    try #require(
      NSEvent.keyEvent(
        with: .keyDown,
        location: .zero,
        modifierFlags: [],
        timestamp: 1,
        windowNumber: number,
        context: nil,
        characters: "\u{7F}",
        charactersIgnoringModifiers: "\u{7F}",
        isARepeat: false,
        keyCode: 51,
      )
    )
  }

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
        try keyDown(inWindowNumbered: number),
        inWindowNumbered: number,
      )
    )
    #expect(
      !ShortcutRecorderMonitor.isTyped(
        try keyDown(inWindowNumbered: number + 1),
        inWindowNumbered: number,
      ),
      "a Delete typed in a pane must not clear the command",
    )
  }
}
