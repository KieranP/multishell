import Foundation
import MultishellProcess
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite
struct PresentedRemovalFailureTests {
  private struct NotAnAlert: Error {
    let failure: PresentedRemovalFailure
  }

  private let refused = ProcessFailure(
    executable: "zsh",
    arguments: ["-l", "-i", "-c", "exit 1"],
    status: 1,
    message: "unpushed",
  )
  private let pruneFailed = ProcessFailure(
    executable: "git",
    arguments: ["worktree", "prune"],
    status: 128,
    message: "fatal: locked",
  )

  @Test func aPreDeleteVetoKeepsTheWorktreeAndSpeaksThroughThePane() {
    let failure = PresentedRemovalFailure(
      HookFailure(stage: .preDelete, underlying: refused),
      deletingBranch: "feat",
    )
    #expect(failure == .vetoed(message: "unpushed\n\nExited with status 1.", didTimeOut: false))
  }

  @Test func aTimedOutPreDeleteHookIsAVetoAndAStoppedOneFailsOnlyAfterRemoval() {
    let timedOut = ProcessFailure(
      executable: "zsh",
      arguments: [],
      status: 129,
      message: "still going",
      stopReason: .timedOut(after: .seconds(60)),
    )
    let failure = PresentedRemovalFailure(
      HookFailure(stage: .preDelete, underlying: timedOut),
      deletingBranch: nil,
    )
    #expect(
      failure
        == .vetoed(
          message: "still going\n\nStopped after 60 seconds, the hook timeout.",
          didTimeOut: true,
        )
    )

    let stopped = ProcessFailure(
      executable: "zsh",
      arguments: [],
      status: 129,
      message: "",
      stopReason: .byUser,
    )
    #expect(
      PresentedRemovalFailure(
        HookFailure(stage: .preDelete, underlying: stopped),
        deletingBranch: nil,
      )
        == .stopped
    )
    let afterRemoval = PresentedRemovalFailure(
      HookFailure(stage: .postDelete, underlying: stopped),
      deletingBranch: "feat",
    )
    #expect(
      afterRemoval
        == .alert(
          title: "Worktree removed, but its hook was stopped",
          message: "Stopped by you and printed nothing.\n\nThe branch feat was kept.",
          retry: nil,
          wasWorktreeRemoved: true,
        ),
      "the worktree is gone; the branch question needs an answer",
    )
  }

  @Test func aTrashRefusalKeepsTheWorktree() throws {
    let error = TrashFailure(
      path: URL(fileURLWithPath: "/trees/x"),
      underlying: CocoaError(.fileWriteVolumeReadOnly),
    )
    let (title, message, retry, removed) = try alert(
      PresentedRemovalFailure(error, deletingBranch: nil)
    )
    #expect(
      title == "Worktree not removed: the directory could not be moved to the Trash or deleted"
    )
    #expect(message.hasPrefix("/trees/x"))
    #expect(retry == nil && !removed)
  }

  /// The directory is in the Trash by then, so the row cannot come back as
  /// it was; the model refreshes and shows what git still lists.
  @Test func aRecordGitWillNotForgetAfterTheTrashIsAnAlertThatRefreshes() throws {
    let error = WorktreeRecordRemovalFailure(
      path: URL(fileURLWithPath: "/trees/x"),
      underlying: pruneFailed,
    )
    let (title, message, retry, removed) = try alert(
      PresentedRemovalFailure(error, deletingBranch: nil)
    )
    #expect(title == "Worktree directory gone, but git still lists it")
    #expect(message.hasPrefix("/trees/x"))
    #expect(retry == nil && removed)
  }

  @Test func aGitFailureBeforeTheDirectoryIsGoneKeepsTheWorktree() throws {
    let (title, message, retry, removed) = try alert(
      PresentedRemovalFailure(pruneFailed, deletingBranch: nil)
    )
    #expect(title == "git worktree prune failed")
    #expect(message == pruneFailed.message)
    #expect(retry == nil && !removed, "the worktree and its terminals come back")
  }

  @Test func aPostDeleteFailureSaysTheBranchWasKeptOnlyWhenItWasToGo() throws {
    let error = HookFailure(stage: .postDelete, underlying: refused)
    let keptBranch = PresentedRemovalFailure(error, deletingBranch: "feat")
    #expect(
      keptBranch
        == .alert(
          title: "Worktree removed, but its hook failed",
          message: "unpushed\n\nExited with status 1.\n\nThe branch feat was kept.",
          retry: nil,
          wasWorktreeRemoved: true,
        )
    )
    let noBranch = try alert(PresentedRemovalFailure(error, deletingBranch: nil))
    #expect(!noBranch.message.contains("was kept"))
  }

  @Test func aBranchThatWouldNotGoOffersTheForcedDelete() throws {
    let error = BranchDeletionFailure(
      branch: "feat",
      underlying: ProcessFailure(
        executable: "git",
        arguments: ["branch", "-d", "feat"],
        status: 1,
        message: "error: the branch 'feat' is not fully merged",
      ),
    )
    let (title, _, retry, removed) = try alert(
      PresentedRemovalFailure(error, deletingBranch: "feat")
    )
    #expect(title == "Worktree removed, but branch feat was not deleted")
    #expect(retry == .deleteBranchAnyway("feat"))
    #expect(retry?.label == "Force Deletion")
    #expect(removed)
  }

  private func alert(
    _ failure: PresentedRemovalFailure
  ) throws -> (
    title: String, message: String, retry: PresentedRemovalFailure.ForcedRetry?, removed: Bool
  ) {
    guard case .alert(let title, let message, let retry, let removed) = failure else {
      throw NotAnAlert(failure: failure)
    }
    return (title, message, retry, removed)
  }
}
