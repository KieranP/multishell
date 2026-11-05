import AppKit
import Testing

@testable import MultishellAppUI

@Suite @MainActor
struct SettingsWindowResetViewTests {
  @Test func theWindowClosingCallsOnCloseOnce() {
    let view = SettingsWindowResetView()
    var closes = 0
    view.onClose = { closes += 1 }
    let window = OffscreenWindow.holding(view, rect: NSRect(x: 0, y: 0, width: 100, height: 100))

    NotificationCenter.default.post(name: NSWindow.willCloseNotification, object: window)

    #expect(closes == 1)
  }
}
