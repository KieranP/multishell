import Foundation
import MultishellGitKit
import MultishellProcess
import Testing

@testable import MultishellAppCore

/// What a failed removal stage shows, for each error the coordinator throws.
@Suite
struct RemovalFailureTests {
  private let refused = ProcessFailure(
    executable: "zsh", arguments: ["-l", "-i", "-c", "exit 1"], status: 1, message: "unpushed")
  private let pruneFailed = ProcessFailure(
    executable: "git", arguments: ["worktree", "prune"], status: 128, message: "fatal: locked")

  @Test func aPreDeleteVetoKeepsTheWorktreeAndSpeaksThroughThePane() {
    let failure = RemovalFailure.describe(
      HookFailure(stage: .preDelete, underlying: refused), deletingBranch: "feat")
    #expect(failure == .vetoed(message: "unpushed\n\nExited with status 1.", timedOut: false))
  }

  @Test func aPreDeleteHookThatTimedOutIsAVetoThatSaysSoAndAStoppedOneIsNotAFailure() {
    let timedOut = ProcessFailure(
      executable: "zsh", arguments: [], status: 129, message: "still going",
      stop: .timedOut(after: .seconds(60)))
    let failure = RemovalFailure.describe(
      HookFailure(stage: .preDelete, underlying: timedOut), deletingBranch: nil)
    #expect(
      failure
        == .vetoed(
          message: "still going\n\nStopped after 60 seconds, the hook timeout.", timedOut: true))

    let stopped = ProcessFailure(
      executable: "zsh", arguments: [], status: 129, message: "", stop: .stopped)
    #expect(
      RemovalFailure.describe(
        HookFailure(stage: .preDelete, underlying: stopped), deletingBranch: nil)
        == .stopped)
    let afterRemoval = RemovalFailure.describe(
      HookFailure(stage: .postDelete, underlying: stopped), deletingBranch: "feat")
    #expect(
      afterRemoval
        == .alert(
          title: "Worktree removed, but its hook was stopped",
          message: "Stopped by you and printed nothing.\n\nThe branch feat was kept.", retry: nil,
          worktreeRemoved: true), "the worktree is gone; the branch question needs an answer")
  }

  @Test func aTrashRefusalKeepsTheWorktree() {
    let error = TrashFailure(
      path: URL(fileURLWithPath: "/trees/x"),
      underlying: CocoaError(.fileWriteVolumeReadOnly))
    guard
      case .alert(let title, let message, let retry, let removed) = RemovalFailure.describe(
        error, deletingBranch: nil)
    else {
      Issue.record("expected an alert")
      return
    }
    #expect(
      title == "Worktree not removed: the directory could not be moved to the Trash or deleted")
    #expect(message.hasPrefix("/trees/x"))
    #expect(retry == nil && !removed)
  }

  /// The directory is in the Trash by then, so the row cannot come back as
  /// it was; the model refreshes and shows what git still lists.
  @Test func aRecordGitWillNotForgetAfterTheTrashIsAnAlertThatRefreshes() {
    let error = WorktreeForgetFailure(
      path: URL(fileURLWithPath: "/trees/x"), underlying: pruneFailed)
    guard
      case .alert(let title, let message, let retry, let removed) = RemovalFailure.describe(
        error, deletingBranch: nil)
    else {
      Issue.record("expected an alert")
      return
    }
    #expect(title == "Worktree in the Trash, but git still lists it")
    #expect(message.hasPrefix("/trees/x"))
    #expect(retry == nil && removed)
  }

  @Test func aGitFailureBeforeTheDirectoryIsGoneKeepsTheWorktree() {
    let failure = RemovalFailure.describe(pruneFailed, deletingBranch: nil)
    guard case .alert(let title, let message, let retry, let removed) = failure else {
      Issue.record("expected an alert")
      return
    }
    #expect(title == "git worktree prune failed")
    #expect(message == pruneFailed.message)
    #expect(retry == nil && !removed, "the worktree and its terminals come back")
  }

  @Test func aPostDeleteFailureSaysTheBranchWasKeptOnlyWhenItWasToGo() {
    let error = HookFailure(stage: .postDelete, underlying: refused)
    let keptBranch = RemovalFailure.describe(error, deletingBranch: "feat")
    #expect(
      keptBranch
        == .alert(
          title: "Worktree removed, but its hook failed",
          message: "unpushed\n\nExited with status 1.\n\nThe branch feat was kept.", retry: nil,
          worktreeRemoved: true))
    let noBranch = RemovalFailure.describe(error, deletingBranch: nil)
    guard case .alert(_, let message, _, _) = noBranch else {
      Issue.record("expected an alert")
      return
    }
    #expect(!message.contains("was kept"))
  }

  @Test func aBranchThatWouldNotGoOffersTheForcedDelete() {
    let error = BranchDeletionFailure(
      branch: "feat",
      underlying: ProcessFailure(
        executable: "git", arguments: ["branch", "-d", "feat"], status: 1,
        message: "error: the branch 'feat' is not fully merged"))
    let failure = RemovalFailure.describe(error, deletingBranch: "feat")
    guard case .alert(let title, _, let retry, let removed) = failure else {
      Issue.record("expected an alert")
      return
    }
    #expect(title == "Worktree removed, but branch feat was not deleted")
    #expect(retry == .deleteBranchAnyway("feat"))
    #expect(retry?.label == "Force Deletion")
    #expect(removed)
  }
}
