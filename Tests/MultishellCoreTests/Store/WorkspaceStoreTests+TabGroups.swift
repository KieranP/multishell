import Foundation
import Testing

@testable import MultishellCore

extension WorkspaceStoreTests {
  @Test func theFirstTabOfAWorktreeOpensAGroupForItself() {
    let (store, _, worktree) = demoStore()
    let tab = store.openTab(in: worktree.id)!

    let groups = store.workspace.groups(in: worktree.id)
    #expect(groups.count == 1)
    #expect(groups[0].activeTabID == tab.id)
    #expect(store.workspace.focusedGroup(in: worktree.id)?.id == groups[0].id)
    #expect(store.workspace.tab(tab.id)?.groupID == groups[0].id)
    WorkspaceInvariants.check(store.workspace, "first tab")
  }

  @Test func aTabDroppedOnABandGetsAGroupOfItsOwn() {
    let (store, _, worktree) = demoStore()
    let staying = store.openTab(in: worktree.id)!
    let moving = store.openTab(in: worktree.id)!
    let first = store.workspace.groups(in: worktree.id)[0]

    let made = store.moveTabToNewGroup(moving.id, .after, of: first.id)

    let groups = store.workspace.groups(in: worktree.id)
    #expect(groups.map(\.id) == [first.id, made?.id], "the new group lands to the right")
    #expect(store.workspace.tabs(in: first.id).map(\.id) == [staying.id])
    #expect(store.workspace.tabs(in: made!.id).map(\.id) == [moving.id])
    #expect(groups[0].activeTabID == staying.id, "the group it left shows what is left")
    #expect(groups[1].activeTabID == moving.id)
    #expect(store.workspace.focusedGroup(in: worktree.id)?.id == made?.id)
    WorkspaceInvariants.check(store.workspace, "new group")
  }

  /// Weights are relative, so what matters is that the two are equal and the total is what the
  /// one group had.
  @Test func aNewGroupTakesHalfTheWidthOfTheOneItLandedBeside() {
    let (store, _, worktree) = demoStore()
    store.openTab(in: worktree.id)
    let moving = store.openTab(in: worktree.id)!
    let first = store.workspace.groups(in: worktree.id)[0]
    let before = first.weight

    store.moveTabToNewGroup(moving.id, .before, of: first.id)

    let weights = store.workspace.groups(in: worktree.id).map(\.weight)
    #expect(weights == [before / 2, before / 2])
  }

  @Test func aGroupWillNotHandOverItsOnlyTab() {
    let (store, _, worktree) = demoStore()
    let tab = store.openTab(in: worktree.id)!
    let only = store.workspace.groups(in: worktree.id)[0]
    let before = store.workspace

    #expect(store.moveTabToNewGroup(tab.id, .after, of: only.id) == nil)
    #expect(store.moveTabToNewGroup(UUID(), .after, of: only.id) == nil, "no such tab")
    #expect(store.moveTabToNewGroup(tab.id, .after, of: UUID()) == nil, "no such group")
    #expect(store.workspace == before, "the same layout under a new id is not a move")
  }

  /// Unlike the no-move above, the group it left goes and a new one arrives at the side it was
  /// dropped on, which is how a group is moved along.
  @Test func theOnlyTabOfAGroupMayStillLandBesideAnother() {
    let (store, _, worktree) = demoStore()
    let staying = store.openTab(in: worktree.id)!
    let moving = store.openTab(in: worktree.id)!
    let first = store.workspace.groups(in: worktree.id)[0]
    let second = store.moveTabToNewGroup(moving.id, .after, of: first.id)!

    let third = store.moveTabToNewGroup(moving.id, .before, of: first.id)

    #expect(third != nil)
    #expect(store.workspace.group(second.id) == nil, "the group it left is gone")
    #expect(store.workspace.groups(in: worktree.id).map(\.id) == [third?.id, first.id])
    #expect(store.workspace.tabs(in: first.id).map(\.id) == [staying.id])
    WorkspaceInvariants.check(store.workspace, "group moved along")
  }

  @Test func aGroupGoesWhenItsLastTabLeaves() {
    let (store, _, worktree) = demoStore()
    let staying = store.openTab(in: worktree.id)!
    let moving = store.openTab(in: worktree.id)!
    let first = store.workspace.groups(in: worktree.id)[0]
    let second = store.moveTabToNewGroup(moving.id, .after, of: first.id)!

    store.moveTab(moving.id, .before, staying.id)

    #expect(store.workspace.groups(in: worktree.id).map(\.id) == [first.id])
    #expect(store.workspace.group(second.id) == nil, "no group stands empty")
    #expect(store.workspace.tabs(in: first.id).map(\.id) == [moving.id, staying.id])
    #expect(store.workspace.focusedGroup(in: worktree.id)?.id == first.id)
    WorkspaceInvariants.check(store.workspace, "group emptied by a move")
  }

  @Test func closingTheLastTabOfAGroupTakesTheGroupWithIt() {
    let (store, _, worktree) = demoStore()
    store.openTab(in: worktree.id)
    let moving = store.openTab(in: worktree.id)!
    let first = store.workspace.groups(in: worktree.id)[0]
    store.moveTabToNewGroup(moving.id, .after, of: first.id)

    store.closeTab(moving.id)

    #expect(store.workspace.groups(in: worktree.id).map(\.id) == [first.id])
    #expect(store.workspace.focusedGroup(in: worktree.id)?.id == first.id)
    WorkspaceInvariants.check(store.workspace, "group emptied by a close")
  }

  /// What a tab strip does when the active tab closes, one level out.
  @Test func theFocusGoesToTheGroupThatTookItsPlace() {
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
      "the group to its right moved up into the slot")

    store.focusGroup(last.id)
    store.closeTab(c.id)
    #expect(
      store.workspace.focusedGroup(in: worktree.id)?.id == first.id,
      "nothing to its right, so the one to its left")
    #expect(store.workspace.tabs.map(\.id) == [a.id])
  }

  @Test func aTabDroppedOnAnotherGroupsTabLandsThereAndShows() {
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
    WorkspaceInvariants.check(store.workspace, "cross-group drop")
  }

  @Test func aTabDroppedOnAGroupsStripLandsLastThere() {
    let (store, _, worktree) = demoStore()
    let settled = store.openTab(in: worktree.id)!
    let moving = store.openTab(in: worktree.id)!
    let first = store.workspace.groups(in: worktree.id)[0]
    let second = store.moveTabToNewGroup(moving.id, .after, of: first.id)!

    #expect(store.moveTab(moving.id, toEndOf: first.id))

    #expect(store.workspace.tabs(in: first.id).map(\.id) == [settled.id, moving.id])
    #expect(store.workspace.group(second.id) == nil)
    #expect(store.moveTab(moving.id, toEndOf: first.id) == false, "already there")
    #expect(store.moveTab(moving.id, toEndOf: UUID()) == false, "no such group")
  }

  @Test func reorderingInsideOneGroupLeavesTheActiveTabAlone() {
    let (store, _, worktree) = demoStore()
    let first = store.openTab(in: worktree.id)!
    let second = store.openTab(in: worktree.id)!
    #expect(store.workspace.activeTab(in: worktree.id)?.id == second.id)

    store.moveTab(first.id, .after, second.id)

    #expect(store.workspace.tabs(in: worktree.id).map(\.id) == [second.id, first.id])
    #expect(store.workspace.activeTab(in: worktree.id)?.id == second.id)
  }

  @Test func aNewTabOpensInTheGroupItWasAskedFor() {
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
      "opening a tab in a group is working in it")
    #expect(store.workspace.group(second.id)?.activeTabID == moving.id, "the other group stands")
  }

  @Test func aTabIsNotOpenedInAnotherWorktreesGroup() {
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

  @Test func groupWeightsAreWrittenBackInOrder() {
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

  @Test func aClickInAPaneFocusesItsGroup() {
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

  @Test func aTabDraggedToAnotherWorktreeLandsInItsFocusedGroup() {
    let (store, project, main) = demoStore()
    let feature = Worktree(
      path: URL(fileURLWithPath: "/repos/demo-b"), projectID: project.id, head: "b",
      branch: "feature")
    store.replaceWorktrees([main, feature], forProject: project.id)
    let settled = store.openTab(in: feature.id)!
    let second = store.openTab(in: feature.id)!
    let firstGroup = store.workspace.groups(in: feature.id)[0]
    let secondGroup = store.moveTabToNewGroup(second.id, .after, of: firstGroup.id)!
    store.focusGroup(firstGroup.id)
    let moving = store.openTab(in: main.id)!

    #expect(store.moveTab(moving.id, to: feature.id))

    #expect(store.workspace.tab(moving.id)?.groupID == firstGroup.id)
    #expect(store.workspace.tabs(in: firstGroup.id).map(\.id) == [settled.id, moving.id])
    #expect(store.workspace.group(secondGroup.id)?.activeTabID == second.id)
    #expect(store.workspace.groups(in: main.id).isEmpty, "the group it left went with it")
    #expect(store.workspace.focusedGroupByWorktree[main.id] == nil)
    WorkspaceInvariants.check(store.workspace, "moved between worktrees")
  }

  @Test func aRemovedWorktreeTakesItsGroups() {
    let (store, project, worktree) = demoStore()
    store.openTab(in: worktree.id)
    let moving = store.openTab(in: worktree.id)!
    store.moveTabToNewGroup(moving.id, .after, of: store.workspace.groups(in: worktree.id)[0].id)

    store.replaceWorktrees([], forProject: project.id)

    #expect(store.workspace.tabGroups.isEmpty)
    #expect(store.workspace.focusedGroupByWorktree.isEmpty)
    WorkspaceInvariants.check(store.workspace, "worktree removed")
  }

  @Test func tabCyclingStaysInsideItsGroup() {
    let (store, _, worktree) = demoStore()
    let a = store.openTab(in: worktree.id)!
    let b = store.openTab(in: worktree.id)!
    let c = store.openTab(in: worktree.id)!
    let first = store.workspace.groups(in: worktree.id)[0]
    store.moveTabToNewGroup(c.id, .after, of: first.id)

    #expect(store.workspace.tab(after: a.id)?.id == b.id)
    #expect(store.workspace.tab(after: b.id)?.id == a.id, "wraps within the group")
    #expect(store.workspace.tab(after: c.id) == nil, "a group of one has nowhere to go")
  }

  /// A file hand-edited to name no focused group, read before repair has
  /// run: the first group answers, so the worktree still draws a strip.
  @Test func aWorktreeWithNoFocusedGroupFallsBackToItsFirst() {
    let (store, _, worktree) = demoStore()
    let tab = store.openTab(in: worktree.id)!
    var workspace = store.workspace
    let first = workspace.groups(in: worktree.id)[0]
    workspace.focusedGroupByWorktree = [:]

    #expect(workspace.focusedGroup(in: worktree.id)?.id == first.id)
    #expect(workspace.activeTab(in: worktree.id)?.id == tab.id)

    workspace.focusedGroupByWorktree[worktree.id] = UUID()
    #expect(workspace.focusedGroup(in: worktree.id)?.id == first.id, "and a group that has gone")
  }

  @Test func onlyOneTabPerGroupCountsAsShown() {
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

  @Test func closingAPaneOfTheLastTabOfAGroupTakesTheGroup() {
    let (store, _, worktree) = demoStore()
    store.openTab(in: worktree.id)
    let moving = store.openTab(in: worktree.id)!
    let first = store.workspace.groups(in: worktree.id)[0]
    store.moveTabToNewGroup(moving.id, .after, of: first.id)

    store.closeSession(moving.focusedSessionID)

    #expect(store.workspace.groups(in: worktree.id).map(\.id) == [first.id])
    WorkspaceInvariants.check(store.workspace, "last pane of a group")
  }
}
