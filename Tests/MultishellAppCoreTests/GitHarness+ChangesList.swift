import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore

extension GitHarness {
  /// A worktree on `feature` with the panel open on its Changes list, the base resolved.
  func featureInChangesList() async throws -> Worktree {
    let feature = try await createWorktree(onBranch: "feature")
    await model.refreshBranchScan(of: project)
    model.select(feature)
    model.setFilesPanelMode(.changes)
    model.setShowsFilesPanel(true)
    return feature
  }

  /// Every status read asked for has landed, so none lands mid-test to start a read itself.
  func statusReadsSettle(_ worktree: Worktree) async throws {
    try await waitUntil {
      model.statuses[worktree.id] != nil && model.pendingStatusRefreshes.isEmpty
        && !model.statusReadLog.isReading(worktree.id)
    }
  }

  /// The tab's last read's counts, `nil` before one holds rows.
  func lineCounts(of tab: FileTab) -> FileLineCounts? {
    if case .text(let rows) = model.fileTabReadings[tab.id]?.content {
      rows.lineCounts
    } else {
      nil
    }
  }
}
