import MultishellGitKit
import Testing

@testable import MultishellAppCore

@Suite
struct WorktreeOperationWordingTests {
  @Test func eachStageHasATitleAndSaysWhatHappensWhenItEnds() {
    let create = WorktreeOperation(.postCreateHook)
    #expect(create.stage == .postCreateHook)
    #expect(create.title == "Running the post-create hook…")
    #expect(create.detail.contains("first terminal opens"))

    let removal = WorktreeOperation(.init(WorktreeRemovalStep.preDeleteHook))
    #expect(removal.stage == .preDeleteHook)
    #expect(removal.detail.contains("stays if the hook refuses"))
    #expect(
      WorktreeOperation(.init(WorktreeRemovalStep.deletingBranch)).title == "Deleting the branch…"
    )
    #expect(
      WorktreeOperation(.init(WorktreeRemovalStep.postDeleteHook)).detail.contains(
        "terminals close"
      )
    )
  }

  @Test func aFailureChangesTheTitleAndTheDetailAndEndsTheRun() {
    #expect(WorktreeOperation(.postCreateHook).isRunning)
    let hook = WorktreeOperation(.postCreateHook, failure: "npm ERR! nope")
    #expect(!hook.isRunning)
    #expect(hook.title == "The post-create hook failed")
    #expect(hook.detail.contains("Dismiss to open its first terminal"))

    let veto = WorktreeOperation(.preDeleteHook, failure: "")
    #expect(veto.title == "The pre-delete hook refused the removal")
    #expect(veto.detail.contains("terminals stay"))
  }

  @Test func theTitleNamesTheTrashOrTheDeleteAndAStepThatFailedOrDidNotFinish() {
    let removing = WorktreeOperation(.removingWorktree)
    #expect(removing.title == "Moving the worktree to the Trash…")
    #expect(removing.detail.contains("in the Trash"))
    let deleting = WorktreeOperation(.deletingWorktree)
    #expect(deleting.title == "Deleting the worktree…")
    #expect(deleting.detail.contains("deleted") && !deleting.detail.contains("Trash"))
    #expect(
      WorktreeOperation(.deletingWorktree, failure: "x").title
        == "The worktree could not be removed"
    )
    #expect(WorktreeOperation(.linkingFiles).title == "Linking files into the worktree…")
    #expect(
      WorktreeOperation(.linkingFiles, failure: "x").title
        == "Some files were not linked into the worktree"
    )
    #expect(
      WorktreeOperation(.removingWorktree, failure: "x").title
        == "The worktree could not be removed"
    )
    let timedOut = WorktreeOperation(.preDeleteHook, failure: "x", didTimeOut: true)
    #expect(timedOut.title == "The pre-delete hook did not finish")
    #expect(
      WorktreeOperation(.postCreateHook, failure: "x", didTimeOut: true).title
        == "The post-create hook did not finish"
    )
  }
}
