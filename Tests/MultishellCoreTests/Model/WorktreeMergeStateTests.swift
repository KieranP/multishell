import Foundation
import Testing

@testable import MultishellCore

/// What the screen reader and the removal dialog say, and which evidence
/// is strong enough to lead with deleting a branch.
@Suite
struct WorktreeMergeStateTests {
  @Test func onlyAncestryAndPatchEquivalenceAreProof() {
    #expect(WorktreeMergeState.merged(.ancestor, into: "origin/main").isCertain)
    #expect(WorktreeMergeState.merged(.patchEquivalent, into: "origin/main").isCertain)
    // A pull request closed without merging leaves the same trace.
    #expect(!WorktreeMergeState.merged(.upstreamGone, into: "origin/main").isCertain)
    #expect(!WorktreeMergeState.unmerged.isCertain)
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

  @Test func onlyALinkedWorktreeOnABranchOfItsOwnCanBeBadged() {
    let main = Worktree(
      path: URL(fileURLWithPath: "/r"), projectID: "/r", head: "a",
      branch: "main", isPrimary: true)
    let trunk = Worktree(
      path: URL(fileURLWithPath: "/t/main"), projectID: "/r", head: "a",
      branch: "main")
    let feat = Worktree(
      path: URL(fileURLWithPath: "/t/feat"), projectID: "/r", head: "a",
      branch: "feat")
    let detached = Worktree(path: URL(fileURLWithPath: "/t/d"), projectID: "/r", head: "abc1234")
    let bare = Worktree(
      path: URL(fileURLWithPath: "/r.git"), projectID: "/r", head: "a",
      isBare: true)

    #expect(WorktreeMergeState.applies(to: feat, base: "main"))
    // The main worktree cannot be removed, so "safe to remove" cannot apply.
    #expect(!WorktreeMergeState.applies(to: main, base: "main"))
    // The trunk's own checkout in a bare layout: not merged into itself.
    #expect(!WorktreeMergeState.applies(to: trunk, base: "main"))
    #expect(!WorktreeMergeState.applies(to: detached, base: "main"))
    #expect(!WorktreeMergeState.applies(to: bare, base: "main"))
  }
}
