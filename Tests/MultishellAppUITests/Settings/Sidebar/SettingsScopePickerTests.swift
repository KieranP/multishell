import AppKit
import MultishellAppCore
import MultishellCore
import SwiftUI
import Testing

@testable import MultishellAppUI

@Suite @MainActor
struct SettingsScopePickerTests {
  @Test(arguments: [false, true])
  func theMenuSpansTheWholeCard(showsProject: Bool) {
    let harness = ModelHarness()
    let scope: SettingsScope = showsProject ? .project(harness.project.id) : .allProjects
    let picker = SettingsScopePicker(model: harness.model, scope: scope)
    let width = 220.0
    let card = NSHostingView(rootView: picker.frame(width: width)).fittingSize

    // SwiftUI builds no accessibility tree offscreen, so the focus ring view it
    // draws at the Menu's frame is the control's only readable trace.
    let menuFrames = OffscreenHost.read(picker, atWidth: width, windowSize: card) { host in
      host.descendants(of: NSView.self)
        .filter { "\(type(of: $0))".contains("FocusRing") }
        .map { $0.convert($0.bounds, to: host) }
    }

    #expect(menuFrames == [CGRect(origin: .zero, size: card)], "expected one ring over the card")
  }
}
