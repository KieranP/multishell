import AppKit
import Testing

@testable import MultishellAppUI

@Suite
@MainActor
struct QuitAlertTests {
  private var alert: NSAlert {
    AppDelegate.quitAlert(terminals: 2, working: 1, quit: "Beenden", cancel: "Abbrechen")
  }

  @Test func theQuitButtonTakesReturn() {
    #expect(alert.buttons.first?.keyEquivalent == "\r")
  }

  /// AppKit binds Escape by matching the title against "Cancel", which a
  /// translated title is not.
  @Test func theCancelButtonTakesEscapeWhateverItIsCalled() {
    #expect(alert.buttons.count == 2)
    #expect(alert.buttons.last?.keyEquivalent == "\u{1b}")
  }
}
