import AppKit
import MultishellCore
import SwiftUI
import Testing

@testable import MultishellAppUI

@Suite @MainActor
struct ViewSegmentedAcrossRowTests {
  @Test func theSettingsPartPickersSpanTheirPage() {
    let harness = ModelHarness()
    let pages: [(String, AnyView)] = [
      ("Agents", AnyView(AgentsSettingsPage(model: harness.model, part: .agent))),
      (
        "Project Hooks",
        AnyView(ProjectHooksPage(model: harness.model, project: harness.project, part: .create))
      ),
    ]
    for (name, page) in pages {
      let widths = page.segmentedControlWidths(inWindowOf: SettingsWindow.size.width)
      #expect(
        widths.count == 1 && widths[0] > SettingsWindow.size.width * 0.75,
        "\(name): \(widths) in \(SettingsWindow.size.width)pt")
    }
  }

  @Test func theNewWorktreeBranchPickerSpansTheSheet() {
    let harness = ModelHarness()
    let sheet = NewWorktreeSheet(model: harness.model, initialProjectID: harness.project.id)
    let width: CGFloat = 520

    let widths = sheet.segmentedControlWidths(inWindowOf: width)

    #expect(widths.count == 1 && widths[0] > width * 0.75, "\(widths) in \(width)pt")
  }
}

extension View {
  @MainActor
  fileprivate func segmentedControlWidths(inWindowOf width: CGFloat) -> [CGFloat] {
    let host = NSHostingView(rootView: frame(width: width))
    let window = OffscreenWindow.holding(
      host, rect: NSRect(x: 0, y: 0, width: width, height: 600), deferred: false)
    return withExtendedLifetime(window) { segmentedControls(in: host).map(\.frame.width) }
  }
}

@MainActor
private func segmentedControls(in view: NSView) -> [NSSegmentedControl] {
  (view as? NSSegmentedControl).map { [$0] } ?? view.subviews.flatMap(segmentedControls)
}
