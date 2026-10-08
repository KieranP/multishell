import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit

@Suite
struct WorktreeMergeStateBadgeTests {
  @Test func theTooltipOffersRemovalOnlyWhereTheEvidenceIsProof() {
    #expect(
      WorktreeMergeState.merged(.ancestor, into: "origin/main").tooltip
        == "Merged into origin/main · safe to remove")
    #expect(
      !WorktreeMergeState.merged(.upstreamGone, into: "origin/main").tooltip
        .contains("safe to remove"))
    #expect(WorktreeMergeState.unmerged.tooltip.isEmpty)
    #expect(WorktreeMergeState.unknown.tooltip.isEmpty)
  }

  /// Work only in this worktree would go to the Trash with the directory, and the badge's
  /// whole claim is that nothing would be lost.
  @Test func uncommittedFilesOrUnpushedCommitsHideTheBadge() {
    let merged = WorktreeMergeState.merged(.ancestor, into: "origin/main")
    #expect(merged.showsBadge(with: WorktreeStatus()))
    #expect(merged.showsBadge(with: nil), "not yet polled; the first poll will hide it")

    var dirty = WorktreeStatus()
    dirty.unstaged = 1
    dirty.changedFiles = 1
    #expect(!merged.showsBadge(with: dirty))

    var untracked = WorktreeStatus()
    untracked.untracked = 1
    untracked.changedFiles = 1
    #expect(!merged.showsBadge(with: untracked))

    var ahead = WorktreeStatus()
    ahead.ahead = 1
    #expect(!merged.showsBadge(with: ahead), "commits the remote has not got")

    var behind = WorktreeStatus()
    behind.behind = 3
    #expect(merged.showsBadge(with: behind), "behind loses nothing on removal")

    #expect(!WorktreeMergeState.unmerged.showsBadge(with: WorktreeStatus()))
    #expect(!WorktreeMergeState.unknown.showsBadge(with: nil), "nothing asked yet")
  }
}
