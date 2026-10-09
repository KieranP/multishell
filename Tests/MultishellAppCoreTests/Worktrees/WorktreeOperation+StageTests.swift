import MultishellGitKit
import Testing

@testable import MultishellAppCore

@Suite
struct WorktreeOperationStageTests {
  @Test func removalStepsMapOntoPaneStages() {
    #expect(WorktreeOperation.Stage(WorktreeRemovalStep.preDeleteHook) == .preDeleteHook)
    #expect(WorktreeOperation.Stage(WorktreeRemovalStep.removingWorktree) == .removingWorktree)
    #expect(WorktreeOperation.Stage(WorktreeRemovalStep.postDeleteHook) == .postDeleteHook)
    #expect(WorktreeOperation.Stage(WorktreeRemovalStep.deletingBranch) == .deletingBranch)
    #expect(
      WorktreeOperation.Stage(WorktreeRemovalStep.removingWorktree, trashes: false)
        == .deletingWorktree
    )
    #expect(
      WorktreeOperation.Stage(WorktreeRemovalStep.postDeleteHook, trashes: false) == .postDeleteHook
    )
  }

  @Test func cancelIsOfferedAtAHookOrAFileStepButNotAtGitsOwnStages() {
    #expect(
      WorktreeOperation.Stage.removingWorktree.cancelHelp == nil,
      "git's own stages are left to finish",
    )
    #expect(WorktreeOperation.Stage.deletingWorktree.cancelHelp == nil)
    #expect(WorktreeOperation.Stage.postCreateHook.cancelHelp?.contains("hook") == true)
    #expect(
      WorktreeOperation.Stage.copyingFiles.cancelHelp?.contains("nothing else runs in it")
        == true,
      "the same Cancel, and what it means where it is not a hook",
    )
  }
}
