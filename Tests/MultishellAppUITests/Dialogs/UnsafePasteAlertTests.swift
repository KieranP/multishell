import AppKit
import Testing

@testable import MultishellAppUI

@Suite
@MainActor
struct UnsafePasteAlertTests {
  private let alert = UnsafePasteAlert.make(text: "ls\nrm -rf build")

  @Test func pasteTakesReturnAndCancelTakesEscape() {
    #expect(alert.buttons.count == 2)
    #expect(alert.buttons.first?.keyEquivalent == "\r")
    #expect(alert.buttons.last?.keyEquivalent == "\u{1b}")
  }

  @Test func theTextIsShownAsItWouldBeTyped() {
    let shown = ((alert.accessoryView as? NSScrollView)?.documentView as? NSTextView)?.string
    #expect(shown == "ls\nrm -rf build")
  }
}
