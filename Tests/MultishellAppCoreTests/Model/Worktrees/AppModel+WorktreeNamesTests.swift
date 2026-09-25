import Testing

@testable import MultishellAppCore
@testable import MultishellCore

/// The field is drawn by a sidebar row the model does not know about, so the model says which
/// worktree is being renamed and what a late commit does.
@Suite @MainActor
struct AppModelWorktreeNamesTests {
  @Test func aCommittedNameReplacesTheBranchAndAnEmptyOneGivesItBack() {
    let h = Harness()
    h.model.setExpanded(false, for: h.project)
    h.model.beginRenamingWorktree(h.feature)
    #expect(h.model.renamingWorktreeID == h.feature.id)
    #expect(
      h.model.workspace.project(h.project.id)?.isExpanded == true,
      "a collapsed project has no row to type into")

    h.model.commitWorktreeRename(of: h.feature.id, to: " Checkout flow ")
    #expect(h.model.renamingWorktreeID == nil)
    #expect(h.model.customName(of: h.feature) == "Checkout flow")
    #expect(h.model.displayName(of: h.feature) == "Checkout flow")
    #expect(h.model.displayName(of: h.main) == "main", "only the one renamed")

    h.model.beginRenamingWorktree(h.feature)
    h.model.commitWorktreeRename(of: h.feature.id, to: "")
    #expect(h.model.customName(of: h.feature) == nil)
    #expect(h.model.displayName(of: h.feature) == "feature")
  }

  /// Escape ends the rename, and the field then loses focus, which is a
  /// commit of whatever was typed. It must not undo the Escape.
  @Test func aCommitAfterCancellingIsIgnored() {
    let h = Harness()
    h.model.renameWorktree(h.feature.id, to: "Checkout flow")
    h.model.beginRenamingWorktree(h.feature)
    h.model.cancelRenamingWorktree()

    h.model.commitWorktreeRename(of: h.feature.id, to: "half-typed")

    #expect(h.model.customName(of: h.feature) == "Checkout flow")
  }

  @Test func renamingAWorktreeThatHasGoneStartsNothing() {
    let h = Harness()
    h.store.replaceWorktrees([h.main], forProject: h.project.id)
    h.model.beginRenamingWorktree(h.feature)
    #expect(h.model.renamingWorktreeID == nil)
  }

  @Test func aRemovedWorktreeTakesItsNameWithIt() {
    let h = Harness()
    h.model.renameWorktree(h.feature.id, to: "Checkout flow")

    // What a removal ends in: git no longer lists it.
    h.store.replaceWorktrees([h.main], forProject: h.project.id)

    #expect(h.model.workspace.worktreeNames.isEmpty, "nothing left in the state file")
  }

}
