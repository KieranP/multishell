import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelTabDragTests {
  func threeTabs(_ harness: Harness) -> [TerminalTab.ID] {
    harness.model.select(harness.main)
    harness.model.newTab()
    harness.model.newTab()
    return order(harness)
  }

  func order(_ harness: Harness) -> [TerminalTab.ID] {
    harness.model.workspace.tabs(in: harness.main.id).map(\.id)
  }

  @Test func aDragNothingTookEndsWithItsSession() {
    let harness = Harness()
    let tabs = threeTabs(harness)
    harness.model.beginTabDrag(tabs[0])

    harness.model.endAbandonedTabDrag(tabs[0])

    #expect(!harness.model.tabDrag.isDragging)
  }

  @Test func aTabShuffledToTheFrontGoesBackToTheEndWhenNothingTakesIt() {
    let harness = Harness()
    let tabs = threeTabs(harness)
    harness.model.beginTabDrag(tabs[2])
    harness.model.shuffleTab(tabs[2], .before, past: tabs[0])

    harness.model.endAbandonedTabDrag(tabs[2])

    #expect(order(harness) == tabs)
  }

  @Test func aTabShuffledToTheEndGoesBackToTheFrontWhenNothingTakesIt() {
    let harness = Harness()
    let tabs = threeTabs(harness)
    harness.model.beginTabDrag(tabs[0])
    harness.model.shuffleTab(tabs[0], .after, past: tabs[1])
    harness.model.shuffleTab(tabs[0], .after, past: tabs[2])

    harness.model.endAbandonedTabDrag(tabs[0])

    #expect(order(harness) == tabs)
  }

  @Test func aTabWhoseNextNeighbourClosedMidDragStillGoesBackToTheFront() {
    let harness = Harness()
    let tabs = threeTabs(harness)
    harness.model.beginTabDrag(tabs[0])
    harness.model.shuffleTab(tabs[0], .after, past: tabs[2])
    harness.model.closeTab(tabs[1])

    harness.model.endAbandonedTabDrag(tabs[0])

    #expect(order(harness) == [tabs[0], tabs[2]])
  }

  @Test func aTabWhoseNeighboursBothClosedMidDragGoesBackBetweenTheTabsLeft() {
    let harness = Harness()
    harness.model.select(harness.main)
    for _ in 0..<4 { harness.model.newTab() }
    let tabs = order(harness)
    harness.model.beginTabDrag(tabs[2])
    harness.model.shuffleTab(tabs[2], .before, past: tabs[0])
    harness.model.closeTab(tabs[1])
    harness.model.closeTab(tabs[3])

    harness.model.endAbandonedTabDrag(tabs[2])

    #expect(order(harness) == [tabs[0], tabs[2], tabs[4]])
  }

  @Test func aDragWhoseTabClosedEndsAndMovesNothing() {
    let harness = Harness()
    let tabs = threeTabs(harness)
    harness.model.beginTabDrag(tabs[2])
    harness.model.shuffleTab(tabs[2], .before, past: tabs[0])
    harness.model.closeTab(tabs[2])

    harness.model.endAbandonedTabDrag(tabs[2])

    #expect(!harness.model.tabDrag.isDragging)
    #expect(order(harness) == [tabs[0], tabs[1]])
  }

  @Test func aShuffleThatADropTookStaysWhereItWasDropped() {
    let harness = Harness()
    let tabs = threeTabs(harness)
    harness.model.beginTabDrag(tabs[2])
    harness.model.shuffleTab(tabs[2], .before, past: tabs[0])
    harness.model.tabDrag.end()

    harness.model.endAbandonedTabDrag(tabs[2])

    #expect(order(harness) == [tabs[2], tabs[0], tabs[1]])
  }

  @Test func theSessionOfAnotherTabLeavesTheDragInTheAir() {
    let harness = Harness()
    let tabs = threeTabs(harness)
    harness.model.beginTabDrag(tabs[1])

    harness.model.endAbandonedTabDrag(tabs[0])

    #expect(harness.model.tabDrag.tabID == tabs[1])
  }

  @Test func aDragWhoseButtonWasRebuiltStaysInTheAirWhileTheButtonIsDown() async {
    let harness = Harness()
    let tabs = threeTabs(harness)
    harness.model.beginTabDrag(tabs[2])
    harness.model.shuffleTab(tabs[2], .before, past: tabs[0])

    harness.model.tabDragSourceLeft(tabs[2], isPressed: { true })
    await harness.settled()

    #expect(harness.model.tabDrag.tabID == tabs[2])
    #expect(order(harness) == [tabs[2], tabs[0], tabs[1]])
  }

  @Test func aDragWhoseButtonWasRebuiltEndsAndGoesBackOnceTheButtonIsUp() async {
    let harness = Harness()
    let tabs = threeTabs(harness)
    let released = Flag()
    harness.model.beginTabDrag(tabs[2])
    harness.model.shuffleTab(tabs[2], .before, past: tabs[0])
    harness.model.tabDragSourceLeft(tabs[2], isPressed: { !released.raised })

    released.raise()
    await harness.model.tabDragReleaseWatch?.value

    #expect(!harness.model.tabDrag.isDragging)
    #expect(order(harness) == tabs)
  }

  @Test func aNewDragOfTheSameTabIsNotEndedByTheLastOnesRelease() async {
    let harness = Harness()
    let tabs = threeTabs(harness)
    let released = Flag()
    harness.model.beginTabDrag(tabs[2])
    harness.model.tabDragSourceLeft(tabs[2], isPressed: { !released.raised })
    let watch = harness.model.tabDragReleaseWatch

    harness.model.beginTabDrag(tabs[2])
    released.raise()
    await watch?.value

    #expect(harness.model.tabDrag.tabID == tabs[2])
  }

  @Test func aDragWhoseButtonLeftWithItsTabClosedEndsAtOnce() {
    let harness = Harness()
    let tabs = threeTabs(harness)
    harness.model.beginTabDrag(tabs[2])
    harness.model.closeTab(tabs[2])

    harness.model.tabDragSourceLeft(tabs[2], isPressed: { true })

    #expect(!harness.model.tabDrag.isDragging)
  }

  @Test func anotherTabsButtonLeavingWatchesNothing() {
    let harness = Harness()
    let tabs = threeTabs(harness)
    harness.model.beginTabDrag(tabs[1])

    harness.model.tabDragSourceLeft(tabs[0], isPressed: { true })

    #expect(harness.model.tabDrag.tabID == tabs[1])
    #expect(harness.model.tabDragReleaseWatch == nil)
  }

  @Test func aModelGoneWhileTheButtonIsDownStopsWatchingIt() throws {
    var harness: Harness? = Harness()
    let tabs = threeTabs(try #require(harness))
    harness?.model.beginTabDrag(tabs[2])
    harness?.model.tabDragSourceLeft(tabs[2], isPressed: { true })
    let watch = try #require(harness?.model.tabDragReleaseWatch)
    weak let model = harness?.model

    harness = nil

    #expect(model == nil)
    #expect(watch.isCancelled)
  }

  /// Dragging a tab along its own strip moves it as the pointer passes each
  /// neighbour, so the tabs make room instead of jumping on release.
  @Test func aTabShufflesAlongItsOwnStripAsItIsDragged() {
    let harness = Harness()
    let tabs = threeTabs(harness)
    let (first, last) = (tabs[0], tabs[tabs.count - 1])

    harness.model.shuffleTab(last, .before, past: first)

    #expect(order(harness).first == last)
    #expect(
      harness.model.workspace.activeTab(in: harness.main.id)?.id == last,
      "reordering does not change which tab is showing")
  }

  /// Repeating the move the pointer is already sitting on must not write the
  /// workspace again: this runs on every few pixels of a drag.
  @Test func shufflingToWhereTheTabAlreadySitsChangesNothing() {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.newTab()
    let tabs = harness.model.workspace.tabs(in: harness.main.id)
    let before = harness.model.workspace

    harness.model.shuffleTab(tabs[1].id, .after, past: tabs[0].id)
    harness.model.shuffleTab(tabs[0].id, .before, past: tabs[1].id)
    harness.model.shuffleTab(tabs[0].id, .after, past: tabs[0].id)

    #expect(harness.model.workspace == before)
  }

  /// Moving a tab into another group live would close the group it left
  /// mid-drag, taking the layout out from under the pointer.
  @Test func aTabDoesNotShuffleIntoAnotherGroup() {
    let harness = Harness()
    _ = threeTabs(harness)
    harness.model.moveActiveTabToNewGroup()
    let groups = harness.model.workspace.groups(in: harness.main.id)
    let staying = harness.model.workspace.shownTab(in: groups[0])!
    let moving = harness.model.workspace.shownTab(in: groups[1])!

    harness.model.shuffleTab(moving.id, .before, past: staying.id)

    #expect(harness.model.workspace.tab(moving.id)?.groupID == groups[1].id)
    #expect(
      !harness.model.workspace.tabs(inGroup: groups[0].id).contains { $0.id == moving.id },
      "it stays out of the group it was dragged over")
  }
}
