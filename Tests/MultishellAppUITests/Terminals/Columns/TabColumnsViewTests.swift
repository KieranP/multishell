import MultishellAppCore
import MultishellCore
import SwiftUI
import Testing

@testable import MultishellAppUI

@Suite @MainActor
struct TabColumnsViewTests {
  private func settle(until done: () -> Bool = { false }, within limit: TimeInterval = 1) {
    let deadline = Date().addingTimeInterval(limit)
    while !done(), Date() < deadline {
      RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01))
    }
  }

  private func threeTabs(_ h: ModelHarness) -> (Worktree, [TerminalTab.ID]) {
    let worktree = Worktree(
      path: h.project.path, projectID: h.project.id, head: "a", branch: "main", isPrimary: true)
    h.store.replaceWorktrees([worktree], forProject: h.project.id)
    h.model.select(worktree)
    h.model.newTab()
    h.model.newTab()
    return (worktree, h.model.workspace.tabs(in: worktree.id).map(\.id))
  }

  private func host(
    _ h: ModelHarness, _ worktree: Worktree, width: CGFloat,
    button: PrimaryMouseButton = PrimaryMouseButton(heldDown: false)
  ) -> NSWindow {
    let host = NSHostingView(
      rootView: TabColumnsView(model: h.model, worktree: worktree, theme: .multishellDark)
        .environment(\.primaryMouseButton, button))
    host.frame = CGRect(x: 0, y: 0, width: width, height: 400)
    let window = NSWindow(
      contentRect: host.frame, styleMask: [.titled], backing: .buffered, defer: true)
    window.contentView = host
    host.layoutSubtreeIfNeeded()
    settle(within: 0.25)
    return window
  }

  @Test func aDragWhoseTabClosesInTheAirEnds() {
    let h = ModelHarness()
    let (worktree, tabs) = threeTabs(h)
    #expect(tabs.count == 3)
    let window = host(h, worktree, width: 800)

    h.model.beginTabDrag(tabs[2])
    h.model.closeTab(tabs[2])
    settle(until: { !h.model.tabDrag.isDragging })

    #expect(!h.model.tabDrag.isDragging)
    withExtendedLifetime(window) {}
  }

  @Test func aDragWhoseStripStopsScrollingStaysInTheAirWhileTheButtonIsDown() {
    let h = ModelHarness()
    let (worktree, tabs) = threeTabs(h)
    let metrics = h.model.metrics
    let window = host(
      h, worktree, width: metrics.newTabMenuWidth + 2 * metrics.tabMinWidth,
      button: PrimaryMouseButton(heldDown: true))
    h.model.beginTabDrag(tabs[2])
    h.model.shuffleTab(tabs[2], .before, past: tabs[0])
    let shuffled = h.model.workspace.tabs(in: worktree.id).map(\.id)

    window.setContentSize(NSSize(width: 1200, height: 400))
    window.contentView?.layoutSubtreeIfNeeded()
    settle(within: 0.25)

    #expect(h.model.tabDrag.tabID == tabs[2])
    #expect(h.model.workspace.tabs(in: worktree.id).map(\.id) == shuffled)
    withExtendedLifetime(window) {}
  }
}
