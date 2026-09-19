import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

// The plain values a tab strip is drawn from. Each runs on every few pixels
// of a drag or a resize, so each is arithmetic kept out of the view.

/// A tab dragged along its own strip moves as the pointer passes each
/// neighbour, so this arithmetic runs on every few pixels of a drag and has
/// to agree with `WorkspaceStore.moveTab` exactly: a disagreement is a tab
/// that moves on every mouse event and never settles.
@Suite
struct TabShuffleTests {
  private let a = UUID()
  private let b = UUID()
  private let c = UUID()
  private var order: [UUID] { [a, b, c] }

  @Test func passingANeighbourReordersTheStrip() {
    #expect(TabShuffle.reorders(a, .after, of: b, in: order))
    #expect(TabShuffle.reorders(c, .before, of: a, in: order))
    #expect(TabShuffle.reorders(b, .after, of: c, in: order))
  }

  /// Where the tab already sits. Each of these is the same strip, and doing
  /// the move would write the workspace on every mouse event for nothing.
  @Test func aMoveThatChangesNothingIsNotOne() {
    #expect(!TabShuffle.reorders(a, .before, of: b, in: order), "already before b")
    #expect(!TabShuffle.reorders(b, .after, of: a, in: order), "already after a")
    #expect(!TabShuffle.reorders(c, .after, of: b, in: order), "already after b")
    #expect(!TabShuffle.reorders(a, .before, of: b, in: [a, b]))
    #expect(!TabShuffle.reorders(b, .after, of: a, in: [a, b]))
  }

  /// The pointer ends up over the tab that just slid under it, and reading
  /// that as an anchor to move it past is how a shuffle oscillates.
  @Test func aTabIsNotAnAnchorForItself() {
    #expect(!TabShuffle.reorders(a, .before, of: a, in: order))
    #expect(!TabShuffle.reorders(a, .after, of: a, in: order))
  }

  @Test func aTabOrAnAnchorThatIsNotInTheStripMovesNothing() {
    #expect(!TabShuffle.reorders(UUID(), .after, of: a, in: order))
    #expect(!TabShuffle.reorders(a, .after, of: UUID(), in: order))
    #expect(!TabShuffle.reorders(a, .after, of: b, in: []))
  }
}

/// A strip that runs out of room has to scroll rather than squeeze: below a
/// floor the icon, the title and the close button run into each other and
/// into the next tab.
@Suite
struct TabStripLayoutTests {
  private func layout(_ available: Double, _ count: Int) -> TabStripLayout {
    TabStripLayout(available: available, count: count, minimum: 100, maximum: 190)
  }

  @Test func tabsTakeTheirFullWidthWhereThereIsRoom() {
    #expect(layout(800, 2).tabWidth == 190)
    #expect(layout(800, 2).scrolls == false)
  }

  @Test func tabsShrinkTogetherAsMoreArrive() {
    #expect(layout(600, 4).tabWidth == 150)
    #expect(layout(600, 5).tabWidth == 120)
    #expect(layout(600, 4).scrolls == false)
  }

  @Test func pastTheFloorTheStripScrollsInsteadOfSqueezing() {
    let tight = layout(600, 7)
    #expect(tight.tabWidth == 100, "the floor, not 85")
    #expect(tight.scrolls)
  }

  /// A strip divides exactly between its tabs, and asking whether the total
  /// overruns the room would be a floating-point coin toss.
  @Test func aStripThatDividesExactlyDoesNotScroll() {
    #expect(layout(300, 3).tabWidth == 100)
    #expect(layout(300, 3).scrolls == false)
  }

  @Test func aStripWithNothingInItOrNotYetLaidOutIsNotScrolling() {
    #expect(layout(800, 0).scrolls == false)
    #expect(layout(.nan, 3).scrolls == false)
    #expect(layout(.nan, 3).tabWidth == 190, "the cap, until it has been laid out")
  }

  /// A window dragged narrow enough leaves a column with less room than the
  /// New Tab button takes. Read as "not scrolling" that would put a
  /// full-width tab in a strip a few points wide and spill it over the
  /// column beside it, which is the whole thing the floor exists to stop.
  @Test func aStripWithNoRoomAtAllStillScrolls() {
    #expect(layout(0, 3).scrolls)
    #expect(layout(-40, 3).scrolls)
    #expect(layout(-40, 3).tabWidth == 100, "the floor, and the row clips")
  }

  @Test func aFloorAboveTheCapWins() {
    let odd = TabStripLayout(available: 600, count: 2, minimum: 200, maximum: 100)
    #expect(odd.tabWidth == 200)
  }
}

/// A strip that scrolls draws an arrow at the end that has tabs past it.
/// Getting this wrong either hides that there is more, or offers an arrow at
/// an end that is already as far as it goes.
@Suite
struct TabStripEdgeTests {
  private func edges(_ offset: Double) -> TabStripLayout.Edges {
    TabStripLayout.Edges(offset: offset, viewport: 300, content: 700)
  }

  @Test func theEndItIsScrolledAwayFromHasMorePastIt() {
    // 700 points of tabs seen through 300, so the travel is 400.
    #expect(edges(200).leading, "200 points of tabs are off to the left")
    #expect(edges(200).trailing, "and 200 more off to the right")
  }

  @Test func eitherEndOfTheTravelSaysNothingIsFurtherThatWay() {
    #expect(!edges(0).leading, "as far left as it goes")
    #expect(edges(0).trailing)
    #expect(edges(400).leading)
    #expect(!edges(400).trailing, "as far right as it goes")
  }

  /// Rounding is what a strip scrolled to its end actually arrives at.
  @Test func aRoundingErrorIsNotMoreTabs() {
    #expect(!edges(0.4).leading)
    #expect(!edges(399.7).trailing)
  }

  @Test func aStripThatFitsHasNothingPastEitherEnd() {
    let fits = TabStripLayout.Edges(offset: 0, viewport: 500, content: 300)
    #expect(!fits.leading && !fits.trailing)
    let odd = TabStripLayout.Edges(offset: .nan, viewport: 300, content: 700)
    #expect(!odd.leading && !odd.trailing)
    let negative = TabStripLayout.Edges(offset: -20, viewport: 300, content: 700)
    #expect(!negative.leading, "rubber-banded past the leading edge")
  }
}

/// What a tab drag is doing. Nothing is drawn from the drag having begun,
/// only from what the pointer is over, because a drag can be released where
/// no target of ours sees it and a highlight would be left behind.
@Suite
struct TabDragStateTests {
  private let tab = UUID()
  private let column = UUID()

  @Test func aDragIsOnlyEngagedWhileItIsOverATarget() {
    var drag = TabDragState()
    #expect(!drag.isDragging && !drag.isEngaged)

    drag.begin(tab)
    #expect(drag.isDragging)
    #expect(!drag.isEngaged, "in the air, over nothing that would take it")

    drag.insertion = TabDragState.Insertion(tabID: tab, placement: .before)
    #expect(drag.isEngaged)
    drag.insertion = nil
    drag.overColumn = column
    #expect(drag.isEngaged)
    drag.overColumn = nil
    drag.band = TabDragState.Band(groupID: column, placement: .after)
    #expect(drag.isEngaged)
  }

  /// The bands sit inside the terminal area they belong to, so the pointer
  /// moving onto one takes it off the area. Reading only the area would put
  /// the bands out the moment one of them was aimed at.
  @Test func aColumnShowsItsBandsFromEitherTheAreaOrTheBands() {
    var drag = TabDragState()
    drag.begin(tab)
    #expect(!drag.showsBands(of: column))

    drag.overColumn = column
    #expect(drag.showsBands(of: column))
    #expect(!drag.showsBands(of: UUID()), "another column's bands stay away")

    drag.overColumn = nil
    drag.band = TabDragState.Band(groupID: column, placement: .before)
    #expect(drag.showsBands(of: column))
  }

  @Test func endingADragClearsEveryTargetWithIt() {
    var drag = TabDragState()
    drag.begin(tab)
    drag.overColumn = column
    drag.insertion = TabDragState.Insertion(tabID: tab, placement: .after)
    drag.band = TabDragState.Band(groupID: column, placement: .after)

    drag.end()

    #expect(drag == TabDragState())
    #expect(!drag.isDragging && !drag.isEngaged)
  }

  /// A second drag starts clean: a target left over from the last one would
  /// draw against a tab that is no longer moving.
  @Test func beginningADragForgetsTheOneBefore() {
    var drag = TabDragState()
    drag.begin(tab)
    drag.band = TabDragState.Band(groupID: column, placement: .after)

    let next = UUID()
    drag.begin(next)

    #expect(drag.tabID == next)
    #expect(!drag.isEngaged)
  }
}

/// Where a strip's arrow scrolls to. 700 points of tabs at 100 each, seen
/// through 300: three and a bit are in view at a time.
@Suite
struct TabStripStepTests {
  private let layout = TabStripLayout(available: 300, count: 7, minimum: 100, maximum: 190)

  private func target(_ placement: TerminalTab.Placement, at offset: Double) -> Int? {
    layout.stepTarget(towards: placement, offset: offset, viewport: 300, count: 7)
  }

  @Test func theStripIsSetUpAsItsTestsAssume() {
    #expect(layout.tabWidth == 100)
    #expect(layout.scrolls)
  }

  @Test func anArrowMovesOnByTheFirstTabPastThatEnd() {
    // Scrolled to the start: tabs 0, 1 and 2 are in view, so the next is 3.
    #expect(target(.after, at: 0) == 3)
    #expect(target(.before, at: 0) == nil, "nothing to the left of the first")

    // Scrolled by two tabs: 2, 3 and 4 are in view.
    #expect(target(.after, at: 200) == 5)
    #expect(target(.before, at: 200) == 1)
  }

  /// A clipped tab is what its arrow finishes. The arrow is drawn from the
  /// same half point, so answering in whole tabs left it dead here.
  @Test func aHalfShownTabIsWhatItsOwnArrowFinishes() {
    // Scrolled by half a tab: 0 is half in view, then 1, 2, and half of 3.
    #expect(target(.before, at: 50) == 0, "half of tab 0 is cut off at the left")
    #expect(target(.after, at: 50) == 3, "and half of tab 3 at the right")
  }

  /// The pair that drew a chevron answering nothing: whatever end `Edges`
  /// fades, `stepTarget` has somewhere to go.
  @Test func everyEndThatFadesCanBeSteppedFrom() {
    for offset in stride(from: 0.0, through: 400, by: 7) {
      let edges = TabStripLayout.Edges(offset: offset, viewport: 300, content: 700)
      #expect(edges.leading == (target(.before, at: offset) != nil), "at \(offset)")
      #expect(edges.trailing == (target(.after, at: offset) != nil), "at \(offset)")
    }
  }

  @Test func theEndOfTheTravelOffersNothingFurther() {
    #expect(target(.after, at: 400) == nil, "tabs 4, 5 and 6 fill the view")
    #expect(target(.before, at: 400) == 3)
  }

  @Test func aStripWithNothingInItOrNotYetScrolledIsAskedNothing() {
    #expect(layout.stepTarget(towards: .after, offset: 0, viewport: 300, count: 0) == nil)
    #expect(layout.stepTarget(towards: .after, offset: .nan, viewport: 300, count: 7) == nil)
    #expect(layout.stepTarget(towards: .before, offset: -40, viewport: 300, count: 7) == nil)
    #expect(
      layout.stepTarget(towards: .after, offset: 0, viewport: 4000, count: 7) == nil,
      "every tab already in view")
  }
}
