import Testing

@testable import MultishellCore

/// What the badge, the screen reader and the removal dialog say, and which
/// evidence is strong enough to lead with deleting a branch.
@Suite
struct WorktreeMergeStateTests {
  @Test func onlyAncestryAndPatchEquivalenceAreProof() {
    #expect(WorktreeMergeState.merged(.ancestor, into: "origin/main").isCertain)
    #expect(WorktreeMergeState.merged(.patchEquivalent, into: "origin/main").isCertain)
    // A pull request closed without merging leaves the same trace.
    #expect(!WorktreeMergeState.merged(.upstreamGone, into: "origin/main").isCertain)
    #expect(!WorktreeMergeState.unmerged.isCertain)
    #expect(!WorktreeMergeState.unknown.isMerged)
  }

  @Test func theTooltipOffersRemovalOnlyWhereTheEvidenceIsProof() {
    #expect(
      WorktreeMergeState.merged(.ancestor, into: "origin/main").help
        == "Merged into origin/main · safe to remove")
    #expect(
      !WorktreeMergeState.merged(.upstreamGone, into: "origin/main").help
        .contains("safe to remove"))
    #expect(WorktreeMergeState.unmerged.help.isEmpty)
  }

  /// Work that is only in this worktree takes the badge away: it would go
  /// to the Trash with the directory, and the badge's whole claim is that
  /// nothing would be lost.
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
  }

  @Test func aRebasedBranchSaysSoSoTheAbsentMergeCommitIsNotAPuzzle() {
    #expect(
      WorktreeMergeState.merged(.patchEquivalent, into: "origin/main").summary
        == "Merged into origin/main, rebased")
  }

  @Test func theRemovalNoteWarnsWhereTheEvidenceIsOnlyAnUpstreamThatHasGone() {
    let certain = WorktreeMergeState.merged(.ancestor, into: "origin/main")
    #expect(certain.removalNote(branch: "feat") == "feat is merged into origin/main.")

    let note = WorktreeMergeState.merged(.upstreamGone, into: "origin/main")
      .removalNote(branch: "feat")
    #expect(note?.contains("squash-merged") == true)
    #expect(note?.contains("closed pull request") == true)

    #expect(WorktreeMergeState.unmerged.removalNote(branch: "feat") == nil)
    #expect(WorktreeMergeState.unknown.removalNote(branch: "feat") == nil)
  }
}
