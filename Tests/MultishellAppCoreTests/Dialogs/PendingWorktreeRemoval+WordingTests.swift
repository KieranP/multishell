import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct PendingWorktreeRemovalWordingTests {
  private let branched = Worktree(
    path: URL(fileURLWithPath: "/trees/feat"), projectID: "/repo", head: "abc", branch: "feat")

  /// The dialog names the row the user right-clicked. The branch is still
  /// in the body: that is the part that cannot be undone.
  @Test func aRenamedWorktreeIsAskedAboutByItsName() {
    let pending = PendingWorktreeRemoval(
      worktree: branched, branchHandling: .offersBoth, customName: "Checkout flow")
    #expect(pending.title == "Remove worktree Checkout flow?")
    #expect(pending.message(warning: nil).hasPrefix("Moves Checkout flow to the Trash"))
    #expect(pending.message(warning: nil).contains("The branch feat is kept unless"))
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

  @Test func changesThatWentUnreadAreWarnedOfWhereverTheDirectoryGoes() {
    #expect(
      PendingWorktreeRemoval.warning(changedFiles: 0, hasUnreadChanges: true, liveTerminals: 0)
        == "Its changes could not be read in time; any it has are kept in the Trash with the directory."
    )
    #expect(
      PendingWorktreeRemoval.warning(
        changedFiles: 0, hasUnreadChanges: true, liveTerminals: 0, trashes: false)
        == "Its changes could not be read in time; any it has are deleted with the directory.")
  }

  @Test func withTheTrashOffTheMessageAndWarningSayTheDirectoryIsDeleted() {
    let deletes = PendingWorktreeRemoval(
      worktree: branched, branchHandling: .offersBoth, trashes: false)
    #expect(deletes.message(warning: nil).hasPrefix("Deletes feat and removes it from git."))
    #expect(
      PendingWorktreeRemoval.warning(changedFiles: 2, liveTerminals: 0, trashes: false)
        == "It has 2 changed files, deleted with the directory.")
  }

  @Test func theMessageNamesTheWorktreeTheBranchsFateAndTheWarning() {
    let offersBoth = PendingWorktreeRemoval(worktree: branched, branchHandling: .offersBoth)
    #expect(
      offersBoth.message(warning: "2 open terminals will be closed.")
        == "Moves feat to the Trash and removes it from git.\n\nThe branch feat is kept unless you remove it too.\n\n2 open terminals will be closed."
    )
    let deletes = PendingWorktreeRemoval(
      worktree: branched, branchHandling: .decided(deletesBranch: true))
    #expect(deletes.message(warning: nil).hasSuffix("The branch feat is deleted with it."))
    let keeps = PendingWorktreeRemoval(
      worktree: branched, branchHandling: .decided(deletesBranch: false))
    #expect(keeps.message(warning: nil).hasSuffix("The branch feat is kept."))
  }
}
