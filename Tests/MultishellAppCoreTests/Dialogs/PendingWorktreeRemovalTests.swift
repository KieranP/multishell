import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct PendingWorktreeRemovalTests {
  private let branched = Worktree(
    path: URL(fileURLWithPath: "/trees/feat"), projectID: "/repo", head: "abc", branch: "feat")
  private let detached = Worktree(
    path: URL(fileURLWithPath: "/trees/pinned"), projectID: "/repo", head: "abc1234")

  /// The dialog the decision asks for, or a failed requirement.
  private func asked(
    _ worktree: Worktree, confirms: Bool, alwaysDeletesBranch: Bool,
    mergeState: WorktreeMergeState = .unknown
  ) throws -> PendingWorktreeRemoval {
    let decision = PendingWorktreeRemoval.decide(
      worktree, confirms: confirms, alwaysDeletesBranch: alwaysDeletesBranch,
      mergeState: mergeState)
    guard case .ask(let pending) = decision else {
      throw RemovalTestFailure(decision: decision)
    }
    return pending
  }

  private struct RemovalTestFailure: Error {
    let decision: PendingWorktreeRemoval.Decision
  }

  @Test func withConfirmationOnTheDialogAsksAboutTheBranchUnlessASettingSettlesIt() throws {
    let pending = try asked(branched, confirms: true, alwaysDeletesBranch: false)
    #expect(pending.choices.count == 2, "one button for the branch, one without it")
    #expect(pending.branchHandling == .asks)
    #expect(pending.primaryRemoveLabel == "Remove Worktree")
    #expect(pending.removeWithBranchLabel == "Remove Worktree and Branch")
    #expect(pending.title == "Remove worktree feat?")

    let settled = try asked(branched, confirms: true, alwaysDeletesBranch: true)
    #expect(settled.choices.count == 1)
    #expect(settled.branchHandling == .decided(deletes: true))
    #expect(
      settled.primaryRemoveLabel == "Remove Worktree and Branch", "one button, saying what it does")
  }

  /// The dialog names the row the user right-clicked. The branch is still
  /// in the body: that is the part that cannot be undone.
  @Test func aRenamedWorktreeIsAskedAboutByItsName() throws {
    let decision = PendingWorktreeRemoval.decide(
      branched, customName: "Checkout flow", confirms: true, alwaysDeletesBranch: false)
    guard case .ask(let pending) = decision else { throw RemovalTestFailure(decision: decision) }
    #expect(pending.title == "Remove worktree Checkout flow?")
    #expect(pending.message(warning: nil).hasPrefix("Moves Checkout flow to the Trash"))
    #expect(pending.message(warning: nil).contains("The branch feat is kept unless"))
  }

  @Test func withConfirmationOffOnlyAnOpenBranchQuestionStillAsks() throws {
    #expect(
      PendingWorktreeRemoval.decide(branched, confirms: false, alwaysDeletesBranch: true)
        == .remove(deletingBranch: true))
    #expect(
      PendingWorktreeRemoval.decide(detached, confirms: false, alwaysDeletesBranch: false)
        == .remove(deletingBranch: false), "nothing to ask about a detached worktree")
    let pending = try asked(branched, confirms: false, alwaysDeletesBranch: false)
    #expect(pending.choices.count == 2, "deleting a branch is not undone from the sidebar")
  }

  @Test func aDetachedWorktreeNeverHasItsBranchDeleted() throws {
    let pending = try asked(detached, confirms: true, alwaysDeletesBranch: true)
    #expect(pending.branchHandling == .decided(deletes: false) && pending.choices.count == 1)
    #expect(pending.primaryRemoveLabel == "Remove Worktree")
    #expect(!pending.message(warning: nil).contains("branch"))
  }

  @Test func theWarningCountsChangedFilesAndOpenTerminalsOrSaysNothing() {
    #expect(PendingWorktreeRemoval.warning(changedFiles: 0, liveTerminals: 0) == nil)
    #expect(
      PendingWorktreeRemoval.warning(changedFiles: 1, liveTerminals: 0)
        == "It has 1 changed file, kept in the Trash with the directory.")
    #expect(
      PendingWorktreeRemoval.warning(changedFiles: 0, liveTerminals: 2)
        == "2 open terminals will be closed.")
    #expect(
      PendingWorktreeRemoval.warning(changedFiles: 3, liveTerminals: 1)
        == "It has 3 changed files, kept in the Trash with the directory. 1 open terminal will be closed."
    )
  }

  @Test func withTheTrashOffTheMessageAndWarningSayTheDirectoryIsDeleted() {
    let deletes = PendingWorktreeRemoval(worktree: branched, branchHandling: .asks, trashes: false)
    #expect(deletes.message(warning: nil).hasPrefix("Deletes feat and removes it from git."))
    #expect(
      PendingWorktreeRemoval.warning(changedFiles: 2, liveTerminals: 0, trashes: false)
        == "It has 2 changed files, deleted with the directory.")
  }

  @Test func theMessageNamesTheWorktreeTheBranchsFateAndTheWarning() {
    let asks = PendingWorktreeRemoval(worktree: branched, branchHandling: .asks)
    #expect(
      asks.message(warning: "2 open terminals will be closed.")
        == "Moves feat to the Trash and removes it from git.\n\nThe branch feat is kept unless you remove it too.\n\n2 open terminals will be closed."
    )
    let deletes = PendingWorktreeRemoval(
      worktree: branched, branchHandling: .decided(deletes: true))
    #expect(deletes.message(warning: nil).hasSuffix("The branch feat is deleted with it."))
    let keeps = PendingWorktreeRemoval(worktree: branched, branchHandling: .decided(deletes: false))
    #expect(keeps.message(warning: nil).hasSuffix("The branch feat is kept."))
  }

  @Test func aMergedBranchLeadsWithTheButtonThatDeletesItAndSaysWhy() throws {
    let decision = PendingWorktreeRemoval.decide(
      branched, confirms: true, alwaysDeletesBranch: false,
      mergeState: .merged(.ancestor, into: "origin/main"))
    guard case .ask(let pending) = decision else { throw RemovalTestFailure(decision: decision) }
    #expect(pending.choices.map(\.deletesBranch) == [true, false])
    #expect(pending.choices.first?.label == "Remove Worktree and Branch")
    #expect(pending.message(warning: nil).contains("feat is merged into origin/main."))
  }

  @Test func anUpstreamThatHasGoneIsNotEnoughToLeadWithDeletingTheBranch() throws {
    let pending = try asked(
      branched, confirms: true, alwaysDeletesBranch: false,
      mergeState: .merged(.upstreamGone, into: "origin/main"))
    #expect(pending.choices.map(\.deletesBranch) == [false, true], "keeping it stays the default")
    #expect(pending.message(warning: nil).contains("likely squash-merged"))
  }

  @Test func aSettledBranchQuestionStillOffersOneButtonWhateverTheMergeState() throws {
    let pending = try asked(
      branched, confirms: true, alwaysDeletesBranch: true,
      mergeState: .merged(.ancestor, into: "origin/main"))
    #expect(
      pending.choices == [
        PendingWorktreeRemoval.Choice(label: "Remove Worktree and Branch", deletesBranch: true)
      ])
  }
}
