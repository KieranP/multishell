import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelTabDragTests {
  func threeTabs(_ h: Harness) -> [TerminalTab.ID] {
    h.model.select(h.main)
    h.model.newTab()
    h.model.newTab()
    return order(h)
  }

  func order(_ h: Harness) -> [TerminalTab.ID] {
    h.model.workspace.tabs(in: h.main.id).map(\.id)
  }

  @Test func aDragNothingTookEndsWithItsSession() {
    let h = Harness()
    let tabs = threeTabs(h)
    h.model.beginTabDrag(tabs[0])

    h.model.endAbandonedTabDrag(tabs[0])

    #expect(!h.model.tabDrag.isDragging)
  }

  @Test func aTabShuffledToTheFrontGoesBackToTheEndWhenNothingTakesIt() {
    let h = Harness()
    let tabs = threeTabs(h)
    h.model.beginTabDrag(tabs[2])
    h.model.shuffleTab(tabs[2], .before, past: tabs[0])

    h.model.endAbandonedTabDrag(tabs[2])

    #expect(order(h) == tabs)
  }

  @Test func aTabShuffledToTheEndGoesBackToTheFrontWhenNothingTakesIt() {
    let h = Harness()
    let tabs = threeTabs(h)
    h.model.beginTabDrag(tabs[0])
    h.model.shuffleTab(tabs[0], .after, past: tabs[1])
    h.model.shuffleTab(tabs[0], .after, past: tabs[2])

    h.model.endAbandonedTabDrag(tabs[0])

    #expect(order(h) == tabs)
  }

  @Test func aTabWhoseNextNeighbourClosedMidDragStillGoesBackToTheFront() {
    let h = Harness()
    let tabs = threeTabs(h)
    h.model.beginTabDrag(tabs[0])
    h.model.shuffleTab(tabs[0], .after, past: tabs[2])
    h.model.closeTab(tabs[1])

    h.model.endAbandonedTabDrag(tabs[0])

    #expect(order(h) == [tabs[0], tabs[2]])
  }

  @Test func aTabWhoseNeighboursBothClosedMidDragGoesBackBetweenTheTabsLeft() {
    let h = Harness()
    h.model.select(h.main)
    for _ in 0..<4 { h.model.newTab() }
    let tabs = order(h)
    h.model.beginTabDrag(tabs[2])
    h.model.shuffleTab(tabs[2], .before, past: tabs[0])
    h.model.closeTab(tabs[1])
    h.model.closeTab(tabs[3])

    h.model.endAbandonedTabDrag(tabs[2])

    #expect(order(h) == [tabs[0], tabs[2], tabs[4]])
  }

  @Test func aDragWhoseTabClosedEndsAndMovesNothing() {
    let h = Harness()
    let tabs = threeTabs(h)
    h.model.beginTabDrag(tabs[2])
    h.model.shuffleTab(tabs[2], .before, past: tabs[0])
    h.model.closeTab(tabs[2])

    h.model.endAbandonedTabDrag(tabs[2])

    #expect(!h.model.tabDrag.isDragging)
    #expect(order(h) == [tabs[0], tabs[1]])
  }

  @Test func aShuffleThatADropTookStaysWhereItWasDropped() {
    let h = Harness()
    let tabs = threeTabs(h)
    h.model.beginTabDrag(tabs[2])
    h.model.shuffleTab(tabs[2], .before, past: tabs[0])
    h.model.tabDrag.end()

    h.model.endAbandonedTabDrag(tabs[2])

    #expect(order(h) == [tabs[2], tabs[0], tabs[1]])
  }

  @Test func theSessionOfAnotherTabLeavesTheDragInTheAir() {
    let h = Harness()
    let tabs = threeTabs(h)
    h.model.beginTabDrag(tabs[1])

    h.model.endAbandonedTabDrag(tabs[0])

    #expect(h.model.tabDrag.tabID == tabs[1])
  }

  @Test func aDragWhoseButtonWasRebuiltStaysInTheAirWhileTheButtonIsDown() async {
    let h = Harness()
    let tabs = threeTabs(h)
    h.model.beginTabDrag(tabs[2])
    h.model.shuffleTab(tabs[2], .before, past: tabs[0])

    h.model.tabDragSourceLeft(tabs[2], isPressed: { true })
    await h.settled()

    #expect(h.model.tabDrag.tabID == tabs[2])
    #expect(order(h) == [tabs[2], tabs[0], tabs[1]])
  }

  @Test func aDragWhoseButtonWasRebuiltEndsAndGoesBackOnceTheButtonIsUp() async {
    let h = Harness()
    let tabs = threeTabs(h)
    let released = Flag()
    h.model.beginTabDrag(tabs[2])
    h.model.shuffleTab(tabs[2], .before, past: tabs[0])
    h.model.tabDragSourceLeft(tabs[2], isPressed: { !released.raised })

    released.raise()
    await h.model.tabDragReleaseWatch?.value

    #expect(!h.model.tabDrag.isDragging)
    #expect(order(h) == tabs)
  }

  @Test func aNewDragOfTheSameTabIsNotEndedByTheLastOnesRelease() async {
    let h = Harness()
    let tabs = threeTabs(h)
    let released = Flag()
    h.model.beginTabDrag(tabs[2])
    h.model.tabDragSourceLeft(tabs[2], isPressed: { !released.raised })
    let watch = h.model.tabDragReleaseWatch

    h.model.beginTabDrag(tabs[2])
    released.raise()
    await watch?.value

    #expect(h.model.tabDrag.tabID == tabs[2])
  }

  @Test func aDragWhoseButtonLeftWithItsTabClosedEndsAtOnce() {
    let h = Harness()
    let tabs = threeTabs(h)
    h.model.beginTabDrag(tabs[2])
    h.model.closeTab(tabs[2])

    h.model.tabDragSourceLeft(tabs[2], isPressed: { true })

    #expect(!h.model.tabDrag.isDragging)
  }

  @Test func anotherTabsButtonLeavingWatchesNothing() {
    let h = Harness()
    let tabs = threeTabs(h)
    h.model.beginTabDrag(tabs[1])

    h.model.tabDragSourceLeft(tabs[0], isPressed: { true })

    #expect(h.model.tabDrag.tabID == tabs[1])
    #expect(h.model.tabDragReleaseWatch == nil)
  }

  @Test func aModelGoneWhileTheButtonIsDownStopsWatchingIt() throws {
    var h: Harness? = Harness()
    let tabs = threeTabs(try #require(h))
    h?.model.beginTabDrag(tabs[2])
    h?.model.tabDragSourceLeft(tabs[2], isPressed: { true })
    let watch = try #require(h?.model.tabDragReleaseWatch)
    weak let model = h?.model

    h = nil

    #expect(model == nil)
    #expect(watch.isCancelled)
  }

  /// Dragging a tab along its own strip moves it as the pointer passes each
  /// neighbour, so the tabs make room instead of jumping on release.
  @Test func aTabShufflesAlongItsOwnStripAsItIsDragged() {
    let h = Harness()
    h.model.select(h.main)
    h.model.newTab()
    h.model.newTab()
    let order = h.model.workspace.tabs(in: h.main.id)
    let (first, last) = (order[0], order[order.count - 1])

    h.model.shuffleTab(last.id, .before, past: first.id)

    #expect(h.model.workspace.tabs(in: h.main.id).first?.id == last.id)
    #expect(
      h.model.workspace.activeTab(in: h.main.id)?.id == last.id,
      "reordering does not change which tab is showing")
  }

  /// Repeating the move the pointer is already sitting on must not write the
  /// workspace again: this runs on every few pixels of a drag.
  @Test func shufflingToWhereTheTabAlreadySitsChangesNothing() {
    let h = Harness()
    h.model.select(h.main)
    h.model.newTab()
    let order = h.model.workspace.tabs(in: h.main.id)
    let before = h.model.workspace

    h.model.shuffleTab(order[1].id, .after, past: order[0].id)
    h.model.shuffleTab(order[0].id, .before, past: order[1].id)
    h.model.shuffleTab(order[0].id, .after, past: order[0].id)

    #expect(h.model.workspace == before)
  }

  /// Moving a tab into another group live would close the group it left
  /// mid-drag, taking the layout out from under the pointer.
  @Test func aTabDoesNotShuffleIntoAnotherGroup() {
    let h = Harness()
    _ = threeTabs(h)
    h.model.moveActiveTabToNewGroup()
    let groups = h.model.workspace.groups(in: h.main.id)
    let staying = h.model.workspace.shownTab(in: groups[0])!
    let moving = h.model.workspace.shownTab(in: groups[1])!

    h.model.shuffleTab(moving.id, .before, past: staying.id)

    #expect(h.model.workspace.tab(moving.id)?.groupID == groups[1].id)
    #expect(
      !h.model.workspace.tabs(inGroup: groups[0].id).contains { $0.id == moving.id },
      "it stays out of the group it was dragged over")
  }
}
