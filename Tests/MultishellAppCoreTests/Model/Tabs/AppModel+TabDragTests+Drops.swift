import MultishellCore
import Testing

@testable import MultishellAppCore

extension AppModelTabDragTests {
  @Test func aTabDroppedOnAnotherWorktreesRowMovesThere() async {
    let harness = Harness()
    let tabs = threeTabs(harness)
    harness.model.beginTabDrag(tabs[2])

    #expect(harness.model.dropDraggedTab(on: .worktree(harness.feature.id)))
    #expect(!harness.model.tabDrag.isDragging)
    await harness.settled()

    #expect(harness.model.workspace.tab(tabs[2])?.worktreeID == harness.feature.id)
  }

  @Test func aTabDroppedOnARowThatThenRefusesGoesBackWhereTheDragFoundIt() async {
    let harness = Harness()
    let tabs = threeTabs(harness)
    harness.model.beginTabDrag(tabs[2])
    harness.model.shuffleTab(tabs[2], .before, past: tabs[0])

    #expect(harness.model.dropDraggedTab(on: .worktree(harness.feature.id)))
    harness.model.worktreeOperations.begin(.removingWorktree, on: harness.feature.id)
    await harness.settled()

    #expect(order(harness) == tabs)
  }

  @Test func aDropOnItsOwnWorktreesRowLeavesTheDragToItsSession() {
    let harness = Harness()
    let tabs = threeTabs(harness)
    harness.model.beginTabDrag(tabs[2])

    #expect(!harness.model.dropDraggedTab(on: .worktree(harness.main.id)))
    #expect(harness.model.tabDrag.tabID == tabs[2])
  }

  @Test func aDropWithNoTabInTheAirIsRefused() throws {
    let harness = Harness()
    let tabs = threeTabs(harness)
    let groupID = try #require(harness.model.workspace.tab(tabs[0])?.groupID)

    #expect(!harness.model.dropDraggedTab(on: .area(groupID)))
    #expect(!harness.model.dropDraggedTab(on: .strip(groupID)))
    #expect(!harness.model.dropDraggedTab(on: .tab(tabs[1], .after)))
    #expect(!harness.model.dropDraggedTab(on: .band(.init(groupID: groupID, placement: .after))))
    #expect(order(harness) == tabs)
  }

  @Test func onlyAnotherWorktreesRowTakesTheDraggedTab() {
    let harness = Harness()
    let tabs = threeTabs(harness)
    #expect(!harness.model.worktreeRowTakesDraggedTab(harness.feature.id))

    harness.model.beginTabDrag(tabs[2])

    #expect(!harness.model.worktreeRowTakesDraggedTab(harness.main.id))
    #expect(harness.model.worktreeRowTakesDraggedTab(harness.feature.id))
  }

  @Test func noRowTakesATabWhileItsOwnWorktreeIsBusy() {
    let harness = Harness()
    let tabs = threeTabs(harness)
    harness.model.beginTabDrag(tabs[2])
    harness.model.worktreeOperations.begin(.removingWorktree, on: harness.main.id)

    #expect(!harness.model.worktreeRowTakesDraggedTab(harness.feature.id))
    #expect(!harness.model.dropDraggedTab(on: .worktree(harness.feature.id)))
  }

  @Test func aBusyWorktreesRowDoesNotTakeTheDraggedTab() {
    let harness = Harness()
    let tabs = threeTabs(harness)
    harness.model.beginTabDrag(tabs[2])
    harness.model.worktreeOperations.begin(.removingWorktree, on: harness.feature.id)

    #expect(!harness.model.worktreeRowTakesDraggedTab(harness.feature.id))
    #expect(!harness.model.dropDraggedTab(on: .worktree(harness.feature.id)))
  }

  @Test func aTabDroppedBesideATabClosedBeforeTheMoveRunsGoesBack() async {
    let harness = Harness()
    _ = threeTabs(harness)
    harness.model.moveActiveTabToNewGroup()
    let groupIDs = harness.model.workspace.groups(in: harness.main.id).map(\.id)
    let first = harness.model.workspace.tabs(inGroup: groupIDs[0]).map(\.id)
    let anchor = harness.model.workspace.tabs(inGroup: groupIDs[1]).map(\.id)[0]
    harness.model.beginTabDrag(first[0])
    harness.model.shuffleTab(first[0], .after, past: first[1])

    #expect(harness.model.dropDraggedTab(on: .tab(anchor, .before)))
    harness.model.closeTab(anchor)
    await harness.settled()

    #expect(harness.model.workspace.tabs(inGroup: groupIDs[0]).map(\.id) == first)
  }

  @Test func aTabDroppedOnItsOwnGroupsTerminalAreaGoesBackWhereTheDragFoundIt() async throws {
    let harness = Harness()
    let tabs = threeTabs(harness)
    let groupID = try #require(harness.model.workspace.tab(tabs[2])?.groupID)
    harness.model.beginTabDrag(tabs[2])
    harness.model.shuffleTab(tabs[2], .before, past: tabs[0])

    #expect(harness.model.dropDraggedTab(on: .area(groupID)))
    await harness.settled()

    #expect(!harness.model.tabDrag.isDragging)
    #expect(order(harness) == tabs)
  }

  @Test func aTabDroppedOnItsOwnStripClearOfTheTabsStaysWhereTheShuffleLeftIt() async throws {
    let harness = Harness()
    let tabs = threeTabs(harness)
    let groupID = try #require(harness.model.workspace.tab(tabs[0])?.groupID)
    harness.model.beginTabDrag(tabs[0])
    harness.model.shuffleTab(tabs[0], .after, past: tabs[2])

    #expect(harness.model.dropDraggedTab(on: .strip(groupID)))
    await harness.settled()

    #expect(order(harness) == [tabs[1], tabs[2], tabs[0]])
  }

  @Test func aTabDroppedOnAnotherGroupsTerminalAreaJoinsIt() async throws {
    let harness = Harness()
    let tabs = threeTabs(harness)
    harness.model.moveActiveTabToNewGroup()
    let other = try #require(harness.model.workspace.tab(tabs[2])?.groupID)
    harness.model.beginTabDrag(tabs[0])

    #expect(harness.model.dropDraggedTab(on: .area(other)))
    await harness.settled()

    #expect(harness.model.workspace.tab(tabs[0])?.groupID == other)
  }

  @Test func aBandThatRefusesTheTabLeavesItWhereItWas() async throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = try #require(order(harness).first)
    let groupID = try #require(harness.model.workspace.tab(tab)?.groupID)
    harness.model.beginTabDrag(tab)

    #expect(harness.model.dropDraggedTab(on: .band(.init(groupID: groupID, placement: .after))))
    await harness.settled()

    #expect(!harness.model.tabDrag.isDragging)
    #expect(harness.model.workspace.groups(in: harness.main.id).count == 1)
  }
}
