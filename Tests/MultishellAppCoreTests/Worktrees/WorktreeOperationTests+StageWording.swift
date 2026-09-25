import Testing

@testable import MultishellAppCore

/// The pane's stage titles, and which stages offer its Cancel.
extension WorktreeOperationTests {
  @Test func thePaneNamesTheTrashAndAHookThatDidNotFinish() {
    let removing = WorktreeOperation(.removingWorktree)
    #expect(removing.title == "Moving the worktree to the Trash…")
    #expect(removing.detail.contains("in the Trash"))
    #expect(removing.step.cancelHelp == nil, "git's own stages are left to finish")
    let deleting = WorktreeOperation(.deletingWorktree)
    #expect(deleting.title == "Deleting the worktree…")
    #expect(deleting.detail.contains("deleted") && !deleting.detail.contains("Trash"))
    #expect(deleting.step.cancelHelp == nil)
    #expect(
      WorktreeOperation(.deletingWorktree, failure: "x").title
        == "The worktree could not be removed")
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
