import AppKit
import Testing

@testable import MultishellAppUI

@Suite @MainActor
struct AccessibilityHiddenViewTests {
  @Test func everyOverlayLaidUnderSwiftUIDerivesFromIt() {
    let overlays: [NSView] = [
      MiddleClickView(), ScrollerMarkerView(), SidewaysWheelView(), WindowAccessorView(),
      SettingsWindowResetView(),
    ]
    for overlay in overlays {
      #expect(overlay is AccessibilityHiddenView, "\(type(of: overlay))")
    }
  }
}
