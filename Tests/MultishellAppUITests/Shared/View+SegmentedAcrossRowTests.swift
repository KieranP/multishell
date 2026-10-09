import AppKit
import MultishellCore
import SwiftUI
import Testing

@testable import MultishellAppUI

@Suite @MainActor
struct ViewSegmentedAcrossRowTests {
  @Test func theSettingsSplitPagePickersSpanTheirPage() {
    let harness = ModelHarness()
    let pages: [(String, AnyView)] = [
      ("Agents", AnyView(AppAgentsPage(model: harness.model, part: .agent))),
      (
        "Project Hooks",
        AnyView(ProjectHooksPage(model: harness.model, project: harness.project, part: .create)),
      ),
    ]
    for (name, page) in pages {
      let width = UIMetrics.settingsWindowSize.width
      let widths = OffscreenHost.read(
        page,
        atWidth: width,
        windowSize: CGSize(width: width, height: 600),
      ) { $0.descendants(of: NSSegmentedControl.self).map(\.frame.width) }
      #expect(
        widths.count == 1 && widths[0] > width * 0.75,
        "\(name): \(widths) in \(width)pt",
      )
    }
  }

  @Test func theNewWorktreeBranchPickerSpansTheSheet() {
    let harness = ModelHarness()
    let sheet = NewWorktreeForm(model: harness.model, initialProjectID: harness.project.id)
    let width = UIMetrics.newWorktreeSheetWidth

    let widths = OffscreenHost.read(
      sheet,
      atWidth: width,
      windowSize: CGSize(width: width, height: 600),
    ) { $0.descendants(of: NSSegmentedControl.self).map(\.frame.width) }

    #expect(widths.count == 1 && widths[0] > width * 0.75, "\(widths) in \(width)pt")
  }
}
