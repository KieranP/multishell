import MultishellCore
import Testing

@testable import MultishellAppCore

extension GitHarness {
  /// On a new `feature` worktree, selected, returned beside the tab.
  func openAllChangesTabOnFeature() async throws -> (AllChangesTab, Worktree) {
    let feature = try await createWorktree(onBranch: "feature")
    await model.refreshBranchScan(of: project)
    model.select(feature)
    let tab = try #require(model.openAllChangesTab(in: feature.id))
    return (tab, feature)
  }

  func allChangesPaths(in tab: AllChangesTab) -> [String]? {
    model.allChangesReadings[tab.id]?.files.map(\.path)
  }
}
