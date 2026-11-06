import AppKit
import Testing

@testable import MultishellAppUI
@testable import MultishellCore

@Suite @MainActor
struct SidebarRowsIdealWidthTests {
  @Test func theFitHoldsALongBranchNameWhole() {
    let harness = ModelHarness()
    let branch = "feature/" + String(repeating: "a-long-branch-name-", count: 8)
    harness.addPrimaryWorktree(branch: branch)
    let metrics = harness.model.metrics
    let font = NSFont.monospacedSystemFont(ofSize: metrics.monospaced, weight: .regular)
    let nameWidth = (branch as NSString).size(withAttributes: [.font: font]).width

    let width = SidebarRows.idealWidth(of: harness.model)

    let insets = metrics.worktreeRowIndent + 2 * UIMetrics.sidebarListSideInset
    #expect(width > nameWidth + insets, "\(width) for a \(nameWidth) pt name")
  }

  @Test func theFitOfShortNamesIsNarrowerThanTheFitOfALongOne() {
    let short = ModelHarness()
    short.addPrimaryWorktree(branch: "main")
    let long = ModelHarness()
    long.addPrimaryWorktree(branch: String(repeating: "long-", count: 30))

    #expect(SidebarRows.idealWidth(of: short.model) < SidebarRows.idealWidth(of: long.model))
  }
}
