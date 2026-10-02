import Testing

@testable import MultishellAppCore
@testable import MultishellCore

/// The field is drawn by a sidebar row the model does not know about, so the model says which
/// worktree is being renamed and what a late commit does.
@Suite @MainActor
struct AppModelWorktreeNamesTests {
  @Test func aCommittedNameReplacesTheBranchAndAnEmptyOneGivesItBack() {
    let harness = Harness()
    harness.model.setExpanded(false, for: harness.project)
    harness.model.beginRenamingWorktree(harness.feature)
    #expect(harness.model.renamingWorktreeID == harness.feature.id)
    #expect(
      harness.project.isExpanded == true,
      "a collapsed project has no row to type into")

    harness.model.commitWorktreeRename(of: harness.feature.id, to: " Checkout flow ")
    #expect(harness.model.renamingWorktreeID == nil)
    #expect(harness.model.customName(of: harness.feature) == "Checkout flow")
    #expect(harness.model.displayName(of: harness.feature) == "Checkout flow")
    #expect(harness.model.displayName(of: harness.main) == "main", "only the one renamed")

    harness.model.beginRenamingWorktree(harness.feature)
    harness.model.commitWorktreeRename(of: harness.feature.id, to: "")
    #expect(harness.model.customName(of: harness.feature) == nil)
    #expect(harness.model.displayName(of: harness.feature) == "feature")
  }

  /// Escape ends the rename, and the field then loses focus, which is a
  /// commit of whatever was typed. It must not undo the Escape.
  @Test func aCommitAfterCancellingIsIgnored() {
    let harness = Harness()
    harness.model.renameWorktree(harness.feature.id, to: "Checkout flow")
    harness.model.beginRenamingWorktree(harness.feature)
    harness.model.cancelRenamingWorktree()

    harness.model.commitWorktreeRename(of: harness.feature.id, to: "half-typed")

    #expect(harness.model.customName(of: harness.feature) == "Checkout flow")
  }

  @Test func renamingAWorktreeThatHasGoneStartsNothing() {
    let harness = Harness()
    harness.store.replaceWorktrees([harness.main], forProject: harness.project.id)
    harness.model.beginRenamingWorktree(harness.feature)
    #expect(harness.model.renamingWorktreeID == nil)
  }

  @Test func aRemovedWorktreeTakesItsNameWithIt() {
    let harness = Harness()
    harness.model.renameWorktree(harness.feature.id, to: "Checkout flow")

    // What a removal ends in: git no longer lists it.
    harness.store.replaceWorktrees([harness.main], forProject: harness.project.id)

    #expect(harness.model.workspace.worktreeNames.isEmpty, "nothing left in the state file")
  }

}
