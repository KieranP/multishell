import AppKit
import SwiftUI
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI
@testable import MultishellCore

@Suite @MainActor
struct SidebarViewTests {
  private func drawnSidebar(_ harness: ModelHarness) throws -> Data? {
    let host = NSHostingView(rootView: SidebarView(model: harness.model))
    host.frame = NSRect(x: 0, y: 0, width: 260, height: 300)
    let window = OffscreenWindow.holding(host, deferred: false)
    let rep = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
    host.cacheDisplay(in: host.bounds, to: rep)
    return withExtendedLifetime(window) { rep.tiffRepresentation }
  }

  @Test func aCollapsedProjectTheFilterOpensDrawsAsAnExpandedOneDoes() throws {
    let harness = ModelHarness()
    let worktree = Worktree(
      path: harness.project.path, projectID: harness.project.id, head: "abc1234",
      branch: "main", isPrimary: true)
    harness.store.replaceWorktrees([worktree], forProject: harness.project.id)
    harness.model.sidebarFilterText = "main"
    harness.model.setExpanded(false, for: harness.project)
    let collapsed = try drawnSidebar(harness)

    harness.model.setExpanded(true, for: harness.project)
    let expanded = try drawnSidebar(harness)

    #expect(collapsed == expanded)
  }
}
