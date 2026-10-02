import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

/// Nothing is drawn from the drag having begun, since a drag can be released where no
/// target of ours sees it and a highlight would be left behind.
@Suite
struct TabDragStateTests {
  private let tab = UUID()
  private let groupID = UUID()

  @Test func aDragIsOnlyEngagedWhileItIsOverATarget() {
    var drag = TabDragState()
    #expect(!drag.isDragging && !drag.isEngaged)

    drag.begin(tab)
    #expect(drag.isDragging)
    #expect(!drag.isEngaged, "in the air, over nothing that would take it")

    drag.insertion = TabDragState.Insertion(tabID: tab, placement: .before)
    #expect(drag.isEngaged)
    drag.insertion = nil
    drag.hoveredGroupID = groupID
    #expect(drag.isEngaged)
    drag.hoveredGroupID = nil
    drag.band = TabGroupBand(groupID: groupID, placement: .after)
    #expect(drag.isEngaged)
  }

  /// The bands sit inside their terminal area, so aiming at one takes the pointer off the
  /// area, and reading only the area would put the bands out.
  @Test func aGroupShowsItsBandsFromEitherTheAreaOrTheBands() {
    var drag = TabDragState()
    drag.begin(tab)
    #expect(!drag.showsBands(of: groupID))

    drag.hoveredGroupID = groupID
    #expect(drag.showsBands(of: groupID))
    #expect(!drag.showsBands(of: UUID()), "another group's bands stay away")

    drag.hoveredGroupID = nil
    drag.band = TabGroupBand(groupID: groupID, placement: .before)
    #expect(drag.showsBands(of: groupID))
  }

  @Test func aStripShufflesOnlyWhenTheTabInTheAirIsOneOfItsOwn() {
    var drag = TabDragState()
    #expect(!drag.isShuffling(within: [tab]))

    drag.begin(tab)
    #expect(drag.isShuffling(within: [UUID(), tab]))
    #expect(!drag.isShuffling(within: [UUID()]), "another group's strip")
  }

  @Test func onlyTheDraggedTabIsHeldOverATargetAndOnlyWhileOverOne() {
    var drag = TabDragState()
    drag.begin(tab)
    #expect(!drag.isHeldOverTarget(tab), "over nothing that would take it")

    drag.hoveredGroupID = groupID
    #expect(drag.isHeldOverTarget(tab))
    #expect(!drag.isHeldOverTarget(UUID()))
  }

  @Test func aHeldTabLooksShuffledInItsOwnStripAndLiftedFromAnother() {
    var drag = TabDragState()
    drag.begin(tab)
    #expect(drag.look(of: tab, isShuffling: true) == .resting, "over nothing yet")

    drag.hoveredGroupID = groupID
    #expect(drag.look(of: tab, isShuffling: true) == .shuffling)
    #expect(drag.look(of: tab, isShuffling: false) == .lifted)
    #expect(drag.look(of: UUID(), isShuffling: false) == .resting)
  }

  @Test func theInsertionLineIsDrawnOnTheTabUnderThePointerUnlessItsStripShuffles() {
    let under = UUID()
    var drag = TabDragState()
    drag.insertion = TabDragState.Insertion(tabID: under, placement: .after)
    #expect(drag.insertionPlacement(on: under, isShuffling: false) == nil, "no drag, no line")

    drag.begin(tab)
    drag.insertion = TabDragState.Insertion(tabID: under, placement: .after)
    #expect(drag.insertionPlacement(on: under, isShuffling: false) == .after)
    #expect(drag.insertionPlacement(on: UUID(), isShuffling: false) == nil)
    #expect(drag.insertionPlacement(on: under, isShuffling: true) == nil, "the tab itself moves")
  }

  @Test func endingADragClearsEveryTargetWithIt() {
    var drag = TabDragState()
    drag.begin(tab)
    drag.hoveredGroupID = groupID
    drag.insertion = TabDragState.Insertion(tabID: tab, placement: .after)
    drag.band = TabGroupBand(groupID: groupID, placement: .after)

    drag.end()

    #expect(drag.tabID == nil && drag.insertion == nil)
    #expect(drag.hoveredGroupID == nil && drag.band == nil)
    #expect(!drag.isDragging && !drag.isEngaged)
  }

  /// A second drag starts clean: a target left over from the last one would
  /// draw against a tab that is no longer moving.
  @Test func beginningADragForgetsTheOneBefore() {
    var drag = TabDragState()
    drag.begin(tab)
    drag.band = TabGroupBand(groupID: groupID, placement: .after)

    let next = UUID()
    drag.begin(next)

    #expect(drag.tabID == next)
    #expect(!drag.isEngaged)
  }
}
