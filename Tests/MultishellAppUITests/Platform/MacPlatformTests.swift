import AppKit
import Testing

@testable import MultishellAppUI

@Suite @MainActor
struct MacPlatformTests {
  @Test func anotherWindowsOcclusionChangeIsNotTheWorkspaceWindowComingBack() {
    let platform = MacPlatform()
    var comebacks = 0
    platform.onWorkspaceWindowDidBecomeVisible = { comebacks += 1 }
    let settings = NSWindow(
      contentRect: .zero,
      styleMask: [.titled],
      backing: .buffered,
      defer: true,
    )

    NotificationCenter.default.post(
      name: NSWindow.didChangeOcclusionStateNotification,
      object: settings,
    )

    #expect(comebacks == 0)
  }
}
