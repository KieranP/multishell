import Foundation
import Testing

@testable import MultishellCore

@MainActor
private func demoStore() -> (store: WorkspaceStore, project: Project, worktree: Worktree) {
  let store = WorkspaceStore()
  let project = store.addProject(at: URL(fileURLWithPath: "/repos/demo"))
  let worktree = Worktree(
    path: URL(fileURLWithPath: "/repos/demo"), projectID: project.id, head: "abc1234",
    branch: "main", isPrimary: true)
  store.replaceWorktrees([worktree], forProject: project.id)
  return (store, project, worktree)
}

/// A worktree's tabs sit in columns side by side; see `TabGroup`. Every test
/// here is one of the moves a drag or a menu item makes, and each must leave
/// the workspace consistent.
@Suite @MainActor
struct TabGroupStoreTests {
  @Test func theFirstTabOfAWorktreeOpensAColumnForItself() {
    let (store, _, worktree) = demoStore()
    let tab = store.openTab(in: worktree.id)!

    let columns = store.workspace.groups(in: worktree.id)
    #expect(columns.count == 1)
    #expect(columns[0].activeTabID == tab.id)
    #expect(store.workspace.focusedGroup(in: worktree.id)?.id == columns[0].id)
    #expect(store.workspace.tab(tab.id)?.groupID == columns[0].id)
    WorkspaceInvariants.check(store.workspace, "first tab")
  }

  @Test func aTabDroppedOnABandGetsAColumnOfItsOwn() {
    let (store, _, worktree) = demoStore()
    let staying = store.openTab(in: worktree.id)!
    let moving = store.openTab(in: worktree.id)!
    let first = store.workspace.groups(in: worktree.id)[0]

    let made = store.moveTabToNewGroup(moving.id, .after, of: first.id)

    let columns = store.workspace.groups(in: worktree.id)
    #expect(columns.map(\.id) == [first.id, made?.id], "the new column lands to the right")
    #expect(store.workspace.tabs(in: first.id).map(\.id) == [staying.id])
    #expect(store.workspace.tabs(in: made!.id).map(\.id) == [moving.id])
    #expect(columns[0].activeTabID == staying.id, "the column it left shows what is left")
    #expect(columns[1].activeTabID == moving.id)
    #expect(store.workspace.focusedGroup(in: worktree.id)?.id == made?.id)
    WorkspaceInvariants.check(store.workspace, "new column")
  }

  /// Half each, the way splitting a pane halves the pane. Weights are
  /// relative, so what matters is that the two are equal and the total is
  /// what the one column had.
  @Test func aNewColumnTakesHalfTheWidthOfTheOneItLandedBeside() {
    let (store, _, worktree) = demoStore()
    store.openTab(in: worktree.id)
    let moving = store.openTab(in: worktree.id)!
    let first = store.workspace.groups(in: worktree.id)[0]
    let before = first.weight

    store.moveTabToNewGroup(moving.id, .before, of: first.id)

    let weights = store.workspace.groups(in: worktree.id).map(\.weight)
    #expect(weights == [before / 2, before / 2])
  }

  @Test func aColumnWillNotHandOverItsOnlyTab() {
    let (store, _, worktree) = demoStore()
    let tab = store.openTab(in: worktree.id)!
    let only = store.workspace.groups(in: worktree.id)[0]
    let before = store.workspace

    #expect(store.moveTabToNewGroup(tab.id, .after, of: only.id) == nil)
    #expect(store.moveTabToNewGroup(UUID(), .after, of: only.id) == nil, "no such tab")
    #expect(store.moveTabToNewGroup(tab.id, .after, of: UUID()) == nil, "no such column")
    #expect(store.workspace == before, "the same layout under a new id is not a move")
  }

  /// A column of one tab dropped on another column's band is not the
  /// no-move above: the column it left goes, and a new one arrives at the
  /// side it was dropped on, which is how a column is moved along.
  @Test func theOnlyTabOfAColumnMayStillLandBesideAnother() {
    let (store, _, worktree) = demoStore()
    let staying = store.openTab(in: worktree.id)!
    let moving = store.openTab(in: worktree.id)!
    let first = store.workspace.groups(in: worktree.id)[0]
    let second = store.moveTabToNewGroup(moving.id, .after, of: first.id)!

    let third = store.moveTabToNewGroup(moving.id, .before, of: first.id)

    #expect(third != nil)
    #expect(store.workspace.group(second.id) == nil, "the column it left is gone")
    #expect(store.workspace.groups(in: worktree.id).map(\.id) == [third?.id, first.id])
    #expect(store.workspace.tabs(in: first.id).map(\.id) == [staying.id])
    WorkspaceInvariants.check(store.workspace, "column moved along")
  }

  @Test func aColumnGoesWhenItsLastTabLeaves() {
    let (store, _, worktree) = demoStore()
    let staying = store.openTab(in: worktree.id)!
    let moving = store.openTab(in: worktree.id)!
    let first = store.workspace.groups(in: worktree.id)[0]
    let second = store.moveTabToNewGroup(moving.id, .after, of: first.id)!

    store.moveTab(moving.id, .before, staying.id)

    #expect(store.workspace.groups(in: worktree.id).map(\.id) == [first.id])
    #expect(store.workspace.group(second.id) == nil, "no column stands empty")
    #expect(store.workspace.tabs(in: first.id).map(\.id) == [moving.id, staying.id])
    #expect(store.workspace.focusedGroup(in: worktree.id)?.id == first.id)
    WorkspaceInvariants.check(store.workspace, "column emptied by a move")
  }

  @Test func closingTheLastTabOfAColumnTakesTheColumnWithIt() {
    let (store, _, worktree) = demoStore()
    store.openTab(in: worktree.id)
    let moving = store.openTab(in: worktree.id)!
    let first = store.workspace.groups(in: worktree.id)[0]
    store.moveTabToNewGroup(moving.id, .after, of: first.id)

    store.closeTab(moving.id)

    #expect(store.workspace.groups(in: worktree.id).map(\.id) == [first.id])
    #expect(store.workspace.focusedGroup(in: worktree.id)?.id == first.id)
    WorkspaceInvariants.check(store.workspace, "column emptied by a close")
  }

  /// The column that slid into its place, or the last one where it was the
  /// rightmost: what a tab strip does when the active tab closes, one level
  /// out.
  @Test func theFocusGoesToTheColumnThatTookItsPlace() {
    let (store, _, worktree) = demoStore()
    let a = store.openTab(in: worktree.id)!
    let b = store.openTab(in: worktree.id)!
    let c = store.openTab(in: worktree.id)!
    let first = store.workspace.groups(in: worktree.id)[0]
    let middle = store.moveTabToNewGroup(b.id, .after, of: first.id)!
    let last = store.moveTabToNewGroup(c.id, .after, of: middle.id)!
    #expect(store.workspace.groups(in: worktree.id).map(\.id) == [first.id, middle.id, last.id])

    store.focusGroup(middle.id)
    store.closeTab(b.id)
    #expect(
      store.workspace.focusedGroup(in: worktree.id)?.id == last.id,
      "the column to its right moved up into the slot")

    store.focusGroup(last.id)
    store.closeTab(c.id)
    #expect(
      store.workspace.focusedGroup(in: worktree.id)?.id == first.id,
      "nothing to its right, so the one to its left")
    #expect(store.workspace.tabs.map(\.id) == [a.id])
  }

  @Test func aTabDroppedOnAnotherColumnsTabLandsThereAndShows() {
    let (store, _, worktree) = demoStore()
    let anchor = store.openTab(in: worktree.id)!
    let neighbour = store.openTab(in: worktree.id)!
    let moving = store.openTab(in: worktree.id)!
    let first = store.workspace.groups(in: worktree.id)[0]
    let second = store.moveTabToNewGroup(moving.id, .after, of: first.id)!
    store.focusGroup(second.id)

    store.moveTab(moving.id, .after, anchor.id)

    #expect(store.workspace.tabs(in: first.id).map(\.id) == [anchor.id, moving.id, neighbour.id])
    #expect(store.workspace.group(second.id) == nil)
    #expect(
      store.workspace.activeTab(in: worktree.id)?.id == moving.id,
      "a tab dragged somewhere is the one being worked in")
    WorkspaceInvariants.check(store.workspace, "cross-column drop")
  }

  @Test func aTabDroppedOnAColumnsStripLandsLastThere() {
    let (store, _, worktree) = demoStore()
    let settled = store.openTab(in: worktree.id)!
    let moving = store.openTab(in: worktree.id)!
    let first = store.workspace.groups(in: worktree.id)[0]
    let second = store.moveTabToNewGroup(moving.id, .after, of: first.id)!

    #expect(store.moveTab(moving.id, toEndOf: first.id))

    #expect(store.workspace.tabs(in: first.id).map(\.id) == [settled.id, moving.id])
    #expect(store.workspace.group(second.id) == nil)
    #expect(store.moveTab(moving.id, toEndOf: first.id) == false, "already there")
    #expect(store.moveTab(moving.id, toEndOf: UUID()) == false, "no such column")
  }

  @Test func reorderingInsideOneColumnLeavesTheActiveTabAlone() {
    let (store, _, worktree) = demoStore()
    let first = store.openTab(in: worktree.id)!
    let second = store.openTab(in: worktree.id)!
    #expect(store.workspace.activeTab(in: worktree.id)?.id == second.id)

    store.moveTab(first.id, .after, second.id)

    #expect(store.workspace.tabs(in: worktree.id).map(\.id) == [second.id, first.id])
    #expect(store.workspace.activeTab(in: worktree.id)?.id == second.id)
  }

  @Test func aNewTabOpensInTheColumnItWasAskedFor() {
    let (store, _, worktree) = demoStore()
    store.openTab(in: worktree.id)
    let moving = store.openTab(in: worktree.id)!
    let first = store.workspace.groups(in: worktree.id)[0]
    let second = store.moveTabToNewGroup(moving.id, .after, of: first.id)!

    let opened = store.openTab(in: worktree.id, group: first.id)!

    #expect(store.workspace.tab(opened.id)?.groupID == first.id)
    #expect(store.workspace.tabs(in: first.id).last?.id == opened.id, "last in that strip")
    #expect(
      store.workspace.focusedGroup(in: worktree.id)?.id == first.id,
      "opening a tab in a column is working in it")
    #expect(store.workspace.group(second.id)?.activeTabID == moving.id, "the other column stands")
  }

  @Test func aTabIsNotOpenedInAnotherWorktreesColumn() {
    let (store, project, main) = demoStore()
    let other = Worktree(
      path: URL(fileURLWithPath: "/repos/demo-b"), projectID: project.id, head: "b", branch: "b")
    store.replaceWorktrees([main, other], forProject: project.id)
    store.openTab(in: main.id)
    let foreign = store.workspace.groups(in: main.id)[0]

    #expect(store.openTab(in: other.id, group: foreign.id) == nil)
    #expect(store.workspace.tabs(in: other.id).isEmpty)
    #expect(store.workspace.sessions(in: other.id).isEmpty, "no session left behind either")
  }

  @Test func columnWeightsAreWrittenBackInOrder() {
    let (store, _, worktree) = demoStore()
    store.openTab(in: worktree.id)
    let moving = store.openTab(in: worktree.id)!
    let first = store.workspace.groups(in: worktree.id)[0]
    store.moveTabToNewGroup(moving.id, .after, of: first.id)

    store.setGroupWeights([3, 1], in: worktree.id)
    #expect(store.workspace.groups(in: worktree.id).map(\.weight) == [3, 1])

    store.setGroupWeights([1], in: worktree.id)
    store.setGroupWeights([1, 0], in: worktree.id)
    store.setGroupWeights([.nan, 1], in: worktree.id)
    #expect(
      store.workspace.groups(in: worktree.id).map(\.weight) == [3, 1],
      "a count that does not line up, a zero and a non-number are all refused")
  }

  @Test func aClickInAPaneFocusesItsColumn() {
    let (store, _, worktree) = demoStore()
    let staying = store.openTab(in: worktree.id)!
    let moving = store.openTab(in: worktree.id)!
    let first = store.workspace.groups(in: worktree.id)[0]
    let second = store.moveTabToNewGroup(moving.id, .after, of: first.id)!
    #expect(store.workspace.focusedGroup(in: worktree.id)?.id == second.id)

    store.focusSession(staying.focusedSessionID)

    #expect(store.workspace.focusedGroup(in: worktree.id)?.id == first.id)
    #expect(store.workspace.activeTab(in: worktree.id)?.id == staying.id)
  }

  @Test func aTabDraggedToAnotherWorktreeLandsInItsFocusedColumn() {
    let (store, project, main) = demoStore()
    let feature = Worktree(
      path: URL(fileURLWithPath: "/repos/demo-b"), projectID: project.id, head: "b",
      branch: "feature")
    store.replaceWorktrees([main, feature], forProject: project.id)
    let settled = store.openTab(in: feature.id)!
    let second = store.openTab(in: feature.id)!
    let firstColumn = store.workspace.groups(in: feature.id)[0]
    let secondColumn = store.moveTabToNewGroup(second.id, .after, of: firstColumn.id)!
    store.focusGroup(firstColumn.id)
    let moving = store.openTab(in: main.id)!

    #expect(store.moveTab(moving.id, to: feature.id))

    #expect(store.workspace.tab(moving.id)?.groupID == firstColumn.id)
    #expect(store.workspace.tabs(in: firstColumn.id).map(\.id) == [settled.id, moving.id])
    #expect(store.workspace.group(secondColumn.id)?.activeTabID == second.id)
    #expect(store.workspace.groups(in: main.id).isEmpty, "the column it left went with it")
    #expect(store.workspace.focusedGroupByWorktree[main.id] == nil)
    WorkspaceInvariants.check(store.workspace, "moved between worktrees")
  }

  @Test func aRemovedWorktreeTakesItsColumns() {
    let (store, project, worktree) = demoStore()
    store.openTab(in: worktree.id)
    let moving = store.openTab(in: worktree.id)!
    store.moveTabToNewGroup(moving.id, .after, of: store.workspace.groups(in: worktree.id)[0].id)

    store.replaceWorktrees([], forProject: project.id)

    #expect(store.workspace.tabGroups.isEmpty)
    #expect(store.workspace.focusedGroupByWorktree.isEmpty)
    WorkspaceInvariants.check(store.workspace, "worktree removed")
  }

  /// Cycling stays inside one column: a strip of two tabs is a two-tab
  /// cycle, whatever the other columns hold.
  @Test func tabCyclingStaysInsideItsColumn() {
    let (store, _, worktree) = demoStore()
    let a = store.openTab(in: worktree.id)!
    let b = store.openTab(in: worktree.id)!
    let c = store.openTab(in: worktree.id)!
    let first = store.workspace.groups(in: worktree.id)[0]
    store.moveTabToNewGroup(c.id, .after, of: first.id)

    #expect(store.workspace.tab(after: a.id)?.id == b.id)
    #expect(store.workspace.tab(after: b.id)?.id == a.id, "wraps within the column")
    #expect(store.workspace.tab(after: c.id) == nil, "a column of one has nowhere to go")
  }

  /// A file hand-edited to name no focused column, read before repair has
  /// run: the first column answers, so the worktree still draws a strip.
  @Test func aWorktreeWithNoFocusedColumnFallsBackToItsFirst() {
    let (store, _, worktree) = demoStore()
    let tab = store.openTab(in: worktree.id)!
    var workspace = store.workspace
    let first = workspace.groups(in: worktree.id)[0]
    workspace.focusedGroupByWorktree = [:]

    #expect(workspace.focusedGroup(in: worktree.id)?.id == first.id)
    #expect(workspace.activeTab(in: worktree.id)?.id == tab.id)

    workspace.focusedGroupByWorktree[worktree.id] = UUID()
    #expect(workspace.focusedGroup(in: worktree.id)?.id == first.id, "and a column that has gone")
  }

  /// One tab per column is on screen, and only those: a tab behind another
  /// in the same strip is not being looked at.
  @Test func onlyOneTabPerColumnCountsAsShown() {
    let (store, _, worktree) = demoStore()
    let hidden = store.openTab(in: worktree.id)!
    let shown = store.openTab(in: worktree.id)!
    let moving = store.openTab(in: worktree.id)!
    let first = store.workspace.groups(in: worktree.id)[0]
    store.moveTabToNewGroup(moving.id, .after, of: first.id)
    store.activateTab(shown.id)

    #expect(
      Set(store.workspace.shownTabs(in: worktree.id).map(\.id)) == [shown.id, moving.id])
    #expect(!store.workspace.shownTabs(in: worktree.id).contains { $0.id == hidden.id })
  }

  @Test func closingAPaneOfTheLastTabOfAColumnTakesTheColumn() {
    let (store, _, worktree) = demoStore()
    store.openTab(in: worktree.id)
    let moving = store.openTab(in: worktree.id)!
    let first = store.workspace.groups(in: worktree.id)[0]
    store.moveTabToNewGroup(moving.id, .after, of: first.id)

    store.closeSession(moving.focusedSessionID)

    #expect(store.workspace.groups(in: worktree.id).map(\.id) == [first.id])
    WorkspaceInvariants.check(store.workspace, "last pane of a column")
  }
}

/// Which tab a column shows once the one it was showing leaves. A strip hands
/// the place to whatever slid into it; see docs/design/tabs-and-columns.md.
@Suite @MainActor
struct ClosedTabSuccessionTests {
  private func column(of worktree: Worktree.ID, in store: WorkspaceStore) -> TabGroup {
    store.workspace.groups(in: worktree)[0]
  }

  @Test func closingTheShownTabShowsItsNeighbourRatherThanTheLastTab() {
    let (store, _, worktree) = demoStore()
    let tabs = (0..<4).map { _ in store.openTab(in: worktree.id)! }
    store.activateTab(tabs[1].id)

    store.closeTab(tabs[1].id)

    #expect(
      column(of: worktree.id, in: store).activeTabID == tabs[2].id,
      "the tab that slid into the closed one's place, not the rightmost")
    WorkspaceInvariants.check(store.workspace, "closed middle tab")
  }

  @Test func closingTheLastTabOfAStripFallsBackToTheOneBeforeIt() {
    let (store, _, worktree) = demoStore()
    let tabs = (0..<3).map { _ in store.openTab(in: worktree.id)! }
    store.activateTab(tabs[2].id)

    store.closeTab(tabs[2].id)

    #expect(column(of: worktree.id, in: store).activeTabID == tabs[1].id)
  }

  /// The same rule for a tab dragged out of a strip: the column it left is a
  /// strip that just lost its shown tab.
  @Test func draggingTheShownTabAwayLeavesItsNeighbourShowing() {
    let (store, _, worktree) = demoStore()
    let tabs = (0..<4).map { _ in store.openTab(in: worktree.id)! }
    let first = column(of: worktree.id, in: store)
    store.activateTab(tabs[1].id)

    store.moveTabToNewGroup(tabs[1].id, .after, of: first.id)

    #expect(store.workspace.group(first.id)?.activeTabID == tabs[2].id)
    WorkspaceInvariants.check(store.workspace, "dragged shown tab out")
  }

  /// The same again for a tab dropped on another column's strip, the third
  /// way a column loses the tab it was showing.
  @Test func droppingTheShownTabOnAnotherColumnLeavesItsNeighbourShowing() {
    let (store, _, worktree) = demoStore()
    let tabs = (0..<4).map { _ in store.openTab(in: worktree.id)! }
    let first = column(of: worktree.id, in: store)
    let made = store.moveTabToNewGroup(tabs[3].id, .after, of: first.id)!
    store.activateTab(tabs[1].id)

    store.moveTab(tabs[1].id, .before, tabs[3].id)

    #expect(store.workspace.group(first.id)?.activeTabID == tabs[2].id)
    #expect(store.workspace.tabs(in: made.id).map(\.id) == [tabs[1].id, tabs[3].id])
    WorkspaceInvariants.check(store.workspace, "moved shown tab across columns")
  }

  @Test func closingATabNobodyWasLookingAtLeavesTheShownOneAlone() {
    let (store, _, worktree) = demoStore()
    let tabs = (0..<3).map { _ in store.openTab(in: worktree.id)! }
    store.activateTab(tabs[2].id)

    store.closeTab(tabs[0].id)

    #expect(column(of: worktree.id, in: store).activeTabID == tabs[2].id)
  }
}
