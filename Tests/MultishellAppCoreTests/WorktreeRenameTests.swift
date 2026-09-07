import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

/// The rename the menus start and the sidebar row's field finishes. The
/// field is drawn by a row the model does not know about, so the model is
/// what says which worktree is being renamed and what a late commit does.
@Suite @MainActor
struct WorktreeRenameTests {
  @Test func aCommittedNameReplacesTheBranchAndAnEmptyOneGivesItBack() {
    let h = Harness()
    h.model.setExpanded(false, for: h.project)
    h.model.beginRenaming(h.feature)
    #expect(h.model.renamingWorktreeID == h.feature.id)
    #expect(
      h.model.workspace.project(h.project.id)?.isExpanded == true,
      "a collapsed project has no row to type into")

    h.model.commitRename(of: h.feature.id, to: " Checkout flow ")
    #expect(h.model.renamingWorktreeID == nil)
    #expect(h.model.customName(of: h.feature) == "Checkout flow")
    #expect(h.model.displayName(of: h.feature) == "Checkout flow")
    #expect(h.model.displayName(of: h.main) == "main", "only the one renamed")

    h.model.beginRenaming(h.feature)
    h.model.commitRename(of: h.feature.id, to: "")
    #expect(h.model.customName(of: h.feature) == nil)
    #expect(h.model.displayName(of: h.feature) == "feature")
  }

  /// Escape ends the rename, and the field then loses focus, which is a
  /// commit of whatever was typed. It must not undo the Escape.
  @Test func aCommitAfterCancellingIsIgnored() {
    let h = Harness()
    h.model.renameWorktree(h.feature.id, to: "Checkout flow")
    h.model.beginRenaming(h.feature)
    h.model.cancelRenaming()

    h.model.commitRename(of: h.feature.id, to: "half-typed")

    #expect(h.model.customName(of: h.feature) == "Checkout flow")
  }

  @Test func renamingAWorktreeThatHasGoneStartsNothing() {
    let h = Harness()
    h.store.replaceWorktrees([h.main], forProject: h.project.id)
    h.model.beginRenaming(h.feature)
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
