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
    drag.overGroup = groupID
    #expect(drag.isEngaged)
    drag.overGroup = nil
    drag.band = TabDragState.Band(groupID: groupID, placement: .after)
    #expect(drag.isEngaged)
  }

  /// The bands sit inside their terminal area, so aiming at one takes the pointer off the
  /// area, and reading only the area would put the bands out.
  @Test func aGroupShowsItsBandsFromEitherTheAreaOrTheBands() {
    var drag = TabDragState()
    drag.begin(tab)
    #expect(!drag.showsBands(of: groupID))

    drag.overGroup = groupID
    #expect(drag.showsBands(of: groupID))
    #expect(!drag.showsBands(of: UUID()), "another group's bands stay away")

    drag.overGroup = nil
    drag.band = TabDragState.Band(groupID: groupID, placement: .before)
    #expect(drag.showsBands(of: groupID))
  }

  @Test func endingADragClearsEveryTargetWithIt() {
    var drag = TabDragState()
    drag.begin(tab)
    drag.overGroup = groupID
    drag.insertion = TabDragState.Insertion(tabID: tab, placement: .after)
    drag.band = TabDragState.Band(groupID: groupID, placement: .after)

    drag.end()

    #expect(drag.tabID == nil && drag.insertion == nil)
    #expect(drag.overGroup == nil && drag.band == nil)
    #expect(!drag.isDragging && !drag.isEngaged)
  }

  /// A second drag starts clean: a target left over from the last one would
  /// draw against a tab that is no longer moving.
  @Test func beginningADragForgetsTheOneBefore() {
    var drag = TabDragState()
    drag.begin(tab)
    drag.band = TabDragState.Band(groupID: groupID, placement: .after)

    let next = UUID()
    drag.begin(next)

    #expect(drag.tabID == next)
    #expect(!drag.isEngaged)
  }
}
