import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelTabMovesTests {
  /// The drop activates the tab in the group it lands in, so the tab that
  /// was showing there goes behind it and must not keep the keyboard.
  @Test func aTabDroppedOnAnotherGroupsTabTakesTheKeyboardWithIt() throws {
    let harness = Harness()
    let a = harness.openBackgroundTab()
    let b = try #require(harness.model.workspace.activeTab(in: harness.main.id))
    harness.model.moveActiveTabToNewGroup()
    harness.model.activate(try #require(harness.model.workspace.tab(a.id)))
    #expect(
      harness.model.workspace.tab(a.id)?.groupID != harness.model.workspace.tab(b.id)?.groupID)
    harness.engine.focused.removeAll()

    harness.model.moveTab(b.id, .before, anchor: a.id)

    #expect(
      harness.model.workspace.tab(b.id)?.groupID == harness.model.workspace.tab(a.id)?.groupID)
    #expect(
      harness.engine.focused.last == harness.model.workspace.tab(b.id)?.focusedSessionID,
      "b is what the group shows now; a is behind it")
  }

  @Test func aTabDraggedOntoAnotherWorktreeGoesThereWithItsShells() {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = harness.model.workspace.activeTab(in: harness.main.id)!
    harness.model.splitActivePane(.vertical)
    let panes = Set(harness.model.workspace.tab(tab.id)!.sessionIDs)

    #expect(harness.model.moveTab(tab.id, toWorktree: harness.feature.id))

    #expect(harness.model.workspace.selectedWorktreeID == harness.feature.id)
    #expect(harness.model.workspace.activeTab(in: harness.feature.id)?.id == tab.id)
    #expect(harness.model.workspace.tabs(in: harness.main.id).isEmpty)
    #expect(panes.isSubset(of: harness.engine.liveSessionIDs), "the shells kept running")
    #expect(harness.engine.closed.isEmpty)
    #expect(
      harness.model.workspace.tabs(in: harness.feature.id).count == 1, "no second tab was opened")
  }

  @Test func aTabIsNotDraggedIntoAWorktreeThatCannotTakeIt() {
    let harness = Harness()
    let gone = Worktree(
      path: URL(fileURLWithPath: "/repos/gone"), projectID: harness.project.id, head: "c",
      branch: "gone")
    harness.store.replaceWorktrees(
      [harness.main, harness.feature, gone], forProject: harness.project.id)
    harness.model.select(harness.main)
    let tab = harness.model.workspace.activeTab(in: harness.main.id)!

    harness.model.worktreeOperations.begin(.removingWorktree, on: harness.feature.id)
    #expect(
      harness.model.moveTab(tab.id, toWorktree: harness.feature.id) == false,
      "a worktree on its way out")
    harness.model.worktreeOperations.clear(harness.feature.id)

    // The other end of the same rule: a tab dragged clear of a removal
    // would be the one thing still running in a trashed directory.
    harness.model.worktreeOperations.begin(.removingWorktree, on: harness.main.id)
    #expect(
      harness.model.moveTab(tab.id, toWorktree: harness.feature.id) == false,
      "dragged out of a removal")
    harness.model.worktreeOperations.clear(harness.main.id)

    harness.model.presentedError = nil
    #expect(harness.model.moveTab(tab.id, toWorktree: gone.id) == false)
    #expect(harness.model.presentedError?.title == "Worktree directory is missing")
    #expect(harness.model.moveTab(tab.id, toWorktree: harness.main.id) == false, "already there")

    #expect(harness.model.workspace.tab(tab.id)?.worktreeID == harness.main.id)
    #expect(harness.model.workspace.selectedWorktreeID == harness.main.id)
  }

  /// Repeating the move a shuffle already made would leave the strip identical
  /// and cost a save and a re-render.
  @Test func aDropOnAMoveAlreadyMadeWritesNothing() {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.newTab()
    let order = harness.model.workspace.tabs(in: harness.main.id)

    harness.model.shuffleTab(order[1].id, .before, past: order[0].id)
    let shuffled = harness.model.workspace

    // What the release does, with the pointer still where it was.
    harness.model.moveTab(order[1].id, .before, anchor: order[0].id)

    #expect(harness.model.workspace == shuffled)
  }

  @Test func aTabDraggedToAnotherWorktreeLeavesNoGroupBehind() {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = harness.model.workspace.activeTab(in: harness.main.id)!
    #expect(harness.model.workspace.tabs(in: harness.main.id).count == 1)

    #expect(harness.model.moveTab(tab.id, toWorktree: harness.feature.id))

    #expect(harness.model.workspace.groups(in: harness.main.id).isEmpty)
    #expect(harness.model.workspace.groups(in: harness.feature.id).count == 1)
    #expect(harness.model.workspace.activeTab(in: harness.feature.id)?.id == tab.id)
  }

  @Test func aTabMovesBeforeOrAfterTheTabItIsDroppedBeside() {
    let harness = Harness()
    let a = harness.openBackgroundTab()
    let b = harness.model.workspace.activeTab(in: harness.main.id)!

    harness.model.moveTab(b.id, .before, anchor: a.id)
    #expect(harness.model.workspace.tabs(in: harness.main.id).map(\.id) == [b.id, a.id])

    harness.model.moveTab(b.id, .after, anchor: a.id)
    #expect(harness.model.workspace.tabs(in: harness.main.id).map(\.id) == [a.id, b.id])
  }

  @Test func aGroupsOnlyTabCannotMoveToANewGroupAndOneOfTwoCan() throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let only = try #require(harness.model.workspace.activeTab(in: harness.main.id))
    #expect(!harness.model.canMoveTabToNewGroup(only))

    harness.model.newTab()

    let first = try #require(harness.model.workspace.tab(only.id))
    #expect(harness.model.canMoveTabToNewGroup(first))
  }
}
