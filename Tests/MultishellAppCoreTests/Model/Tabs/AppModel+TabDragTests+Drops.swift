import MultishellCore
import Testing

@testable import MultishellAppCore

extension AppModelTabDragTests {
  @Test func aTabDroppedOnAnotherWorktreesRowMovesThere() async {
    let h = Harness()
    let tabs = threeTabs(h)
    h.model.beginTabDrag(tabs[2])

    #expect(h.model.dropDraggedTab(on: .worktree(h.feature.id)))
    #expect(!h.model.tabDrag.isDragging)
    await h.settled()

    #expect(h.model.workspace.tab(tabs[2])?.worktreeID == h.feature.id)
  }

  @Test func aTabARowRefusesAfterTheDropGoesBackWhereTheDragFoundIt() async {
    let h = Harness()
    let tabs = threeTabs(h)
    h.model.beginTabDrag(tabs[2])
    h.model.shuffleTab(tabs[2], .before, past: tabs[0])

    #expect(h.model.dropDraggedTab(on: .worktree(h.feature.id)))
    h.model.worktreeOperations.begin(.removingWorktree, on: h.feature.id)
    await h.settled()

    #expect(order(h) == tabs)
  }

  @Test func aDropOnItsOwnWorktreesRowLeavesTheDragToItsSession() {
    let h = Harness()
    let tabs = threeTabs(h)
    h.model.beginTabDrag(tabs[2])

    #expect(!h.model.dropDraggedTab(on: .worktree(h.main.id)))
    #expect(h.model.tabDrag.tabID == tabs[2])
  }

  @Test func aDropWithNoTabInTheAirIsRefused() throws {
    let h = Harness()
    let tabs = threeTabs(h)
    let groupID = try #require(h.model.workspace.tab(tabs[0])?.groupID)

    #expect(!h.model.dropDraggedTab(on: .area(groupID)))
    #expect(!h.model.dropDraggedTab(on: .strip(groupID)))
    #expect(!h.model.dropDraggedTab(on: .tab(tabs[1], .after)))
    #expect(!h.model.dropDraggedTab(on: .band(.init(groupID: groupID, placement: .after))))
    #expect(order(h) == tabs)
  }

  @Test func onlyAnotherWorktreesRowTakesTheDraggedTab() {
    let h = Harness()
    let tabs = threeTabs(h)
    #expect(!h.model.worktreeRowTakesDraggedTab(h.feature.id))

    h.model.beginTabDrag(tabs[2])

    #expect(!h.model.worktreeRowTakesDraggedTab(h.main.id))
    #expect(h.model.worktreeRowTakesDraggedTab(h.feature.id))
  }

  @Test func noRowTakesATabWhileItsOwnWorktreeIsBusy() {
    let h = Harness()
    let tabs = threeTabs(h)
    h.model.beginTabDrag(tabs[2])
    h.model.worktreeOperations.begin(.removingWorktree, on: h.main.id)

    #expect(!h.model.worktreeRowTakesDraggedTab(h.feature.id))
    #expect(!h.model.dropDraggedTab(on: .worktree(h.feature.id)))
  }

  @Test func aBusyWorktreesRowDoesNotTakeTheDraggedTab() {
    let h = Harness()
    let tabs = threeTabs(h)
    h.model.beginTabDrag(tabs[2])
    h.model.worktreeOperations.begin(.removingWorktree, on: h.feature.id)

    #expect(!h.model.worktreeRowTakesDraggedTab(h.feature.id))
    #expect(!h.model.dropDraggedTab(on: .worktree(h.feature.id)))
  }

  @Test func aTabDroppedBesideATabClosedBeforeTheMoveRunsGoesBack() async {
    let h = Harness()
    _ = threeTabs(h)
    h.model.moveActiveTabToNewGroup()
    let groupIDs = h.model.workspace.groups(in: h.main.id).map(\.id)
    let first = h.model.workspace.tabs(inGroup: groupIDs[0]).map(\.id)
    let anchor = h.model.workspace.tabs(inGroup: groupIDs[1]).map(\.id)[0]
    h.model.beginTabDrag(first[0])
    h.model.shuffleTab(first[0], .after, past: first[1])

    #expect(h.model.dropDraggedTab(on: .tab(anchor, .before)))
    h.model.closeTab(anchor)
    await h.settled()

    #expect(h.model.workspace.tabs(inGroup: groupIDs[0]).map(\.id) == first)
  }

  @Test func aTabDroppedOnItsOwnGroupsTerminalAreaGoesBackWhereTheDragFoundIt() async throws {
    let h = Harness()
    let tabs = threeTabs(h)
    let groupID = try #require(h.model.workspace.tab(tabs[2])?.groupID)
    h.model.beginTabDrag(tabs[2])
    h.model.shuffleTab(tabs[2], .before, past: tabs[0])

    #expect(h.model.dropDraggedTab(on: .area(groupID)))
    await h.settled()

    #expect(!h.model.tabDrag.isDragging)
    #expect(order(h) == tabs)
  }

  @Test func aTabDroppedOnItsOwnStripClearOfTheTabsStaysWhereTheShuffleLeftIt() async throws {
    let h = Harness()
    let tabs = threeTabs(h)
    let groupID = try #require(h.model.workspace.tab(tabs[0])?.groupID)
    h.model.beginTabDrag(tabs[0])
    h.model.shuffleTab(tabs[0], .after, past: tabs[2])

    #expect(h.model.dropDraggedTab(on: .strip(groupID)))
    await h.settled()

    #expect(order(h) == [tabs[1], tabs[2], tabs[0]])
  }

  @Test func aTabDroppedOnAnotherGroupsTerminalAreaJoinsIt() async throws {
    let h = Harness()
    let tabs = threeTabs(h)
    h.model.moveActiveTabToNewGroup()
    let other = try #require(h.model.workspace.tab(tabs[2])?.groupID)
    h.model.beginTabDrag(tabs[0])

    #expect(h.model.dropDraggedTab(on: .area(other)))
    await h.settled()

    #expect(h.model.workspace.tab(tabs[0])?.groupID == other)
  }

  @Test func aBandThatRefusesTheTabLeavesItWhereItWas() async throws {
    let h = Harness()
    h.model.select(h.main)
    let tab = try #require(order(h).first)
    let groupID = try #require(h.model.workspace.tab(tab)?.groupID)
    h.model.beginTabDrag(tab)

    #expect(h.model.dropDraggedTab(on: .band(.init(groupID: groupID, placement: .after))))
    await h.settled()

    #expect(!h.model.tabDrag.isDragging)
    #expect(h.model.workspace.groups(in: h.main.id).count == 1)
  }
}
