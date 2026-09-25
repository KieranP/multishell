import MultishellGitKit
import Testing

@testable import MultishellAppCore

@Suite
struct WorktreeOperationTests {
  @Test func eachStepHasATitleAndSaysWhatHappensWhenItEnds() {
    let create = WorktreeOperation(.postCreateHook)
    #expect(create.step == .postCreateHook)
    #expect(create.title == "Running the post-create hook…")
    #expect(create.detail.contains("first terminal opens"))

    let removal = WorktreeOperation(.init(WorktreeRemovalStep.preDeleteHook))
    #expect(removal.step == .preDeleteHook)
    #expect(removal.detail.contains("stays if the hook refuses"))
    #expect(
      WorktreeOperation(.init(WorktreeRemovalStep.deletingBranch)).title == "Deleting the branch…")
    #expect(
      WorktreeOperation(.init(WorktreeRemovalStep.postDeleteHook)).detail.contains(
        "terminals close"))
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
