import AppKit
import SwiftUI
import Testing

@testable import MultishellAppUI

@MainActor
@Suite
struct GhosttyPaneEventMonitorTests {
  @Test func aClickOnTheTopPaneOfAStackedSplitFindsTheTopPane() {
    let content = NSHostingView(rootView: Color.clear)
    content.frame = NSRect(x: 0, y: 0, width: 400, height: 400)
    let window = OffscreenWindow.holding(content)
    let top = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
    let bottom = NSView(frame: NSRect(x: 0, y: 200, width: 400, height: 200))
    content.addSubview(top)
    content.addSubview(bottom)
    let nearTheTop = content.convert(NSPoint(x: 200, y: 20), to: nil)

    withExtendedLifetime(window) {
      #expect(GhosttyPaneEventMonitor.view(at: nearTheTop, in: window) === top)
    }
  }
}
