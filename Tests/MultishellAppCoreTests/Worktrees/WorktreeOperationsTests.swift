import MultishellGitKit
import Testing

@testable import MultishellAppCore

/// Who owns a worktree's operation entry, on the plain value the model and
/// the pane read.
@Suite
struct WorktreeOperationsTests {
  private let a = "/trees/a"
  private let b = "/trees/b"

  @Test func aStageBeginsAdvancesAndFinishesOnlyWhileItIsTheOneRunning() {
    var operations = WorktreeOperations()
    operations.begin(.preDeleteHook, on: a)
    #expect(operations.isBusy(a) && !operations.isBusy(b))
    operations.advance(to: .removingWorktree, on: a)
    #expect(operations[a]?.step == .removingWorktree)

    let otherStage = operations.finish(.postCreateHook, on: a)
    #expect(!otherStage, "another stage's ending changes nothing")
    #expect(operations[a]?.step == .removingWorktree)
    let ownStage = operations.finish(.removingWorktree, on: a)
    #expect(ownStage)
    #expect(operations.isEmpty)
  }

  /// The bug this guards: a post-create hook still running when the user
  /// asks for a removal must not, on ending, clear the removal's stage or
  /// put its own failure over it.
  @Test func aRemovalTakesTheEntryFromARunningPostCreateHook() {
    var operations = WorktreeOperations()
    operations.begin(.postCreateHook, on: a)
    operations.begin(.preDeleteHook, on: a)

    let finished = operations.finish(.postCreateHook, on: a)
    let failed = operations.fail(.postCreateHook, on: a, message: "npm ERR!")
    #expect(!finished && !failed)
    #expect(operations[a] == WorktreeOperation(.preDeleteHook), "the removal's entry is untouched")
  }

  @Test func aFailureHoldsTheEntryUntilDismissedAndIgnoresLaterStages() {
    var operations = WorktreeOperations()
    operations.begin(.postCreateHook, on: a)
    let recorded = operations.fail(.postCreateHook, on: a, message: "exit 3")
    #expect(recorded)
    #expect(operations[a]?.failure == "exit 3")
    #expect(operations.isBusy(a))

    operations.advance(to: .removingWorktree, on: a)
    #expect(operations[a]?.step == .postCreateHook, "a failed entry does not advance")
    let finished = operations.finish(.postCreateHook, on: a)
    #expect(!finished, "nor does it finish on its own")

    let dismissed = operations.dismiss(a)
    #expect(dismissed?.step == .postCreateHook && dismissed?.failure == "exit 3")
    #expect(operations.isEmpty)
  }

  @Test func dismissLeavesARunningOperationAloneAndClearTakesAnything() {
    var operations = WorktreeOperations()
    operations.begin(.removingWorktree, on: a)
    #expect(operations.dismiss(a) == nil)
    #expect(operations.isBusy(a))
    operations.clear(a)
    #expect(operations.isEmpty)
    #expect(operations.dismiss(b) == nil, "nothing there")
  }

  @Test func removalStepsMapOntoPaneSteps() {
    #expect(WorktreeOperation.Step(WorktreeRemovalStep.preDeleteHook) == .preDeleteHook)
    #expect(WorktreeOperation.Step(WorktreeRemovalStep.removingWorktree) == .removingWorktree)
    #expect(WorktreeOperation.Step(WorktreeRemovalStep.postDeleteHook) == .postDeleteHook)
    #expect(WorktreeOperation.Step(WorktreeRemovalStep.deletingBranch) == .deletingBranch)
  }
}

@Suite
struct WorktreeOperationTests {
  @Test func eachStepHasATitleAndSaysWhatHappensWhenItEnds() {
    let create = WorktreeOperation(.postCreateHook)
    #expect(create.step == .postCreateHook)
    #expect(create.title == "Running the post-create hook…")
    #expect(create.detail.contains("first terminal opens"))

    let removal = WorktreeOperation(WorktreeRemovalStep.preDeleteHook)
    #expect(removal.step == .preDeleteHook)
    #expect(removal.detail.contains("stays if the hook refuses"))
    #expect(WorktreeOperation(WorktreeRemovalStep.deletingBranch).title == "Deleting the branch…")
    #expect(
      WorktreeOperation(WorktreeRemovalStep.removingWorktree).detail
        == WorktreeOperation(WorktreeRemovalStep.postDeleteHook).detail)
  }

  @Test func aFailureChangesTheTitleAndTheDetailAndEndsTheRun() {
    var hook = WorktreeOperation(.postCreateHook)
    #expect(hook.isRunning)
    hook.failure = "npm ERR! nope"
    #expect(!hook.isRunning)
    #expect(hook.title == "The post-create hook failed")
    #expect(hook.detail.contains("Dismiss to open its first terminal"))

    let veto = WorktreeOperation(.preDeleteHook, failure: "")
    #expect(veto.title == "The pre-delete hook refused the removal")
    #expect(veto.detail.contains("terminals stay"))
  }
}

/// The pane's stage titles, and which stages offer its Cancel.
@Suite
struct RemovalStageWordingTests {
  @Test func thePaneNamesTheTrashAndAHookThatDidNotFinish() {
    let removing = WorktreeOperation(.removingWorktree)
    #expect(removing.title == "Moving the worktree to the Trash…")
    #expect(removing.detail.contains("in the Trash"))
    #expect(removing.step.cancelHelp == nil, "git's own stages are left to finish")
    #expect(WorktreeOperation(.postCreateHook).step.cancelHelp?.contains("hook") == true)
    #expect(
      WorktreeOperation(.copyingFiles).step.cancelHelp?.contains("nothing else runs in it") == true,
      "the same Cancel, and what it means where it is not a hook")
    #expect(WorktreeOperation(.linkingFiles).title == "Linking files into the worktree…")
    #expect(
      WorktreeOperation(.linkingFiles, failure: "x").title
        == "Some files were not linked into the worktree")
    #expect(
      WorktreeOperation(.removingWorktree, failure: "x").title
        == "The worktree could not be removed")
    let timedOut = WorktreeOperation(.preDeleteHook, failure: "x", timedOut: true)
    #expect(timedOut.title == "The pre-delete hook did not finish")
    #expect(
      WorktreeOperation(.postCreateHook, failure: "x", timedOut: true).title
        == "The post-create hook did not finish")
  }
}
