import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelTabMovesTests {
  /// The drop activates the tab in the group it lands in, so the tab that
  /// was showing there goes behind it and must not keep the keyboard.
  @Test func aTabDroppedOnAnotherGroupsTabTakesTheKeyboardWithIt() throws {
    let h = Harness()
    h.model.select(h.main)
    let a = try #require(h.model.workspace.activeTab(in: h.main.id))
    h.model.newTab()
    let b = try #require(h.model.workspace.activeTab(in: h.main.id))
    h.model.moveActiveTabToNewGroup()
    h.model.activate(try #require(h.model.workspace.tab(a.id)))
    #expect(h.model.workspace.tab(a.id)?.groupID != h.model.workspace.tab(b.id)?.groupID)
    h.engine.focused.removeAll()

    h.model.moveTab(b.id, .before, anchor: a.id)

    #expect(h.model.workspace.tab(b.id)?.groupID == h.model.workspace.tab(a.id)?.groupID)
    #expect(
      h.engine.focused.last == h.model.workspace.tab(b.id)?.focusedSessionID,
      "b is what the group shows now; a is behind it")
  }

  @Test func aTabDraggedOntoAnotherWorktreeGoesThereWithItsShells() {
    let h = Harness()
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!
    h.model.splitActivePane(.vertical)
    let panes = Set(h.model.workspace.tab(tab.id)!.sessionIDs)

    #expect(h.model.moveTab(tab.id, toWorktree: h.feature.id))

    #expect(h.model.workspace.selectedWorktreeID == h.feature.id)
    #expect(h.model.workspace.activeTab(in: h.feature.id)?.id == tab.id)
    #expect(h.model.workspace.tabs(in: h.main.id).isEmpty)
    #expect(panes.isSubset(of: h.engine.liveSessionIDs), "the shells kept running")
    #expect(h.engine.closed.isEmpty)
    #expect(h.model.workspace.tabs(in: h.feature.id).count == 1, "no second tab was opened")
  }

  @Test func aTabIsNotDraggedIntoAWorktreeThatCannotTakeIt() {
    let h = Harness()
    let gone = Worktree(
      path: URL(fileURLWithPath: "/repos/gone"), projectID: h.project.id, head: "c",
      branch: "gone")
    h.store.replaceWorktrees([h.main, h.feature, gone], forProject: h.project.id)
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!

    h.model.worktreeOperations.begin(.removingWorktree, on: h.feature.id)
    #expect(h.model.moveTab(tab.id, toWorktree: h.feature.id) == false, "a worktree on its way out")
    h.model.worktreeOperations.clear(h.feature.id)

    // The other end of the same rule: a tab dragged clear of a removal
    // would be the one thing still running in a trashed directory.
    h.model.worktreeOperations.begin(.removingWorktree, on: h.main.id)
    #expect(h.model.moveTab(tab.id, toWorktree: h.feature.id) == false, "dragged out of a removal")
    h.model.worktreeOperations.clear(h.main.id)

    h.model.presentedError = nil
    #expect(h.model.moveTab(tab.id, toWorktree: gone.id) == false)
    #expect(h.model.presentedError?.title == "Worktree directory is missing")
    #expect(h.model.moveTab(tab.id, toWorktree: h.main.id) == false, "already there")

    #expect(h.model.workspace.tab(tab.id)?.worktreeID == h.main.id)
    #expect(h.model.workspace.selectedWorktreeID == h.main.id)
  }

  /// Repeating the move a shuffle already made would leave the strip identical
  /// and cost a save and a re-render.
  @Test func aDropOnAMoveAlreadyMadeWritesNothing() {
    let h = Harness()
    h.model.select(h.main)
    h.model.newTab()
    let order = h.model.workspace.tabs(in: h.main.id)

    h.model.shuffleTab(order[1].id, .before, past: order[0].id)
    let shuffled = h.model.workspace

    // What the release does, with the pointer still where it was.
    h.model.moveTab(order[1].id, .before, anchor: order[0].id)

    #expect(h.model.workspace == shuffled)
  }

  @Test func aTabDraggedToAnotherWorktreeLeavesNoGroupBehind() {
    let h = Harness()
    // Selecting opens the worktree's first tab, and that one tab is the
    // whole of its only group.
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!
    #expect(h.model.workspace.tabs(in: h.main.id).count == 1)

    #expect(h.model.moveTab(tab.id, toWorktree: h.feature.id))

    #expect(h.model.workspace.groups(in: h.main.id).isEmpty)
    #expect(h.model.workspace.groups(in: h.feature.id).count == 1)
    #expect(h.model.workspace.activeTab(in: h.feature.id)?.id == tab.id)
  }
}
