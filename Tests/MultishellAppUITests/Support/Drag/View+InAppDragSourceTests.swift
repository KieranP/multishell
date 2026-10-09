import MultishellAppCore
import SwiftUI
import Testing

@testable import MultishellAppUI
@testable import MultishellCore

@Suite @MainActor
struct ViewInAppDragSourceTests {
  private func threeTabs(_ harness: ModelHarness) -> (Worktree, [TerminalTab.ID]) {
    let worktree = harness.addPrimaryWorktree(head: "a")
    harness.model.select(worktree)
    harness.model.newTab()
    harness.model.newTab()
    return (worktree, harness.model.workspace.tabs(in: worktree.id).map(\.id))
  }

  private func host(
    _ harness: ModelHarness,
    _ worktree: Worktree,
    width: CGFloat,
    button: PrimaryMouseButton = PrimaryMouseButton(isPressedOverride: false),
  ) -> NSWindow {
    let host = NSHostingView(
      rootView: WorktreeTabGroups(model: harness.model, worktree: worktree, theme: .multishellDark)
        .environment(\.primaryMouseButton, button)
    )
    host.frame = CGRect(x: 0, y: 0, width: width, height: 400)
    let window = OffscreenWindow.holding(host)
    OffscreenWindow.settle(within: 0.25)
    return window
  }

  @Test func aDragWhoseTabClosesInTheAirEnds() {
    let harness = ModelHarness()
    let (worktree, tabs) = threeTabs(harness)
    #expect(tabs.count == 3)
    let window = host(harness, worktree, width: 800)

    harness.model.beginTabDrag(tabs[2])
    harness.model.closeTab(tabs[2])
    OffscreenWindow.settle(until: { !harness.model.tabDrag.isDragging }, within: 1)

    #expect(!harness.model.tabDrag.isDragging)
    withExtendedLifetime(window) {}
  }

  @Test func aDragWhoseStripStopsScrollingStaysInTheAirWhileTheButtonIsDown() {
    let harness = ModelHarness()
    let (worktree, tabs) = threeTabs(harness)
    let metrics = harness.model.metrics
    let window = host(
      harness,
      worktree,
      width: metrics.newTabMenuWidth + 2 * metrics.tabMinWidth,
      button: PrimaryMouseButton(isPressedOverride: true),
    )
    harness.model.beginTabDrag(tabs[2])
    harness.model.shuffleTab(tabs[2], .before, past: tabs[0])
    let shuffled = harness.model.workspace.tabs(in: worktree.id).map(\.id)

    window.setContentSize(NSSize(width: 1200, height: 400))
    window.contentView?.layoutSubtreeIfNeeded()
    OffscreenWindow.settle(within: 0.25)

    #expect(harness.model.tabDrag.tabID == tabs[2])
    #expect(harness.model.workspace.tabs(in: worktree.id).map(\.id) == shuffled)
    withExtendedLifetime(window) {}
  }
}
