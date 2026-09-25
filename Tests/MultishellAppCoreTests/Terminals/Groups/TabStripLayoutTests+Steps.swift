import MultishellCore
import Testing

@testable import MultishellAppCore

/// Where a strip's arrow scrolls to. 700 points of tabs at 100 each, seen
/// through 300: three and a bit are in view at a time.
extension TabStripLayoutTests {
  private var layout: TabStripLayout {
    TabStripLayout(available: 300, count: 7, minimum: 100, maximum: 190)
  }

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
