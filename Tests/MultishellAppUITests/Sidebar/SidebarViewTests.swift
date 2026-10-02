import AppKit
import SwiftUI
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI
@testable import MultishellCore

@Suite @MainActor
struct SidebarViewTests {
  private func drawnSidebar(_ harness: ModelHarness) throws -> Data? {
    try #require(
      OffscreenWindow.pixels(
        ofHosted: SidebarView(model: harness.model), size: CGSize(width: 260, height: 300))
    ).tiffRepresentation
  }

  @Test func aCollapsedProjectTheFilterOpensDrawsAsAnExpandedOneDoes() throws {
    let harness = ModelHarness()
    harness.addPrimaryWorktree()
    harness.model.sidebarFilterText = "main"
    harness.model.setExpanded(false, for: harness.project)
    let collapsed = try drawnSidebar(harness)

    harness.model.setExpanded(true, for: harness.project)
    let expanded = try drawnSidebar(harness)

    #expect(collapsed == expanded)
  }
}
