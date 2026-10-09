import MultishellCore
import Testing

@testable import MultishellAppCore

/// Where a strip's arrow scrolls to. 700 points of tabs at 100 each, seen
/// through 300: three and a bit are in view at a time.
@Suite
struct TabStripLayoutStepsTests {
  private var layout: TabStripLayout {
    TabStripLayout(available: 300, count: 7, minimum: 100, maximum: 190)
  }

  private func target(_ end: TabStripLayout.End, at offset: Double) -> Int? {
    layout.stepTarget(towards: end, offset: offset, viewport: 300, count: 7)
  }

  @Test func anArrowMovesOnByTheFirstTabPastThatEnd() {
    #expect(target(.trailing, at: 0) == 3, "0 to 2 in view at the start")
    #expect(target(.leading, at: 0) == nil, "nothing to the left of the first")

    #expect(target(.trailing, at: 200) == 5, "2 to 4 in view two tabs on")
    #expect(target(.leading, at: 200) == 1)
  }

  /// A clipped tab is what its arrow finishes. The arrow is drawn from the
  /// same half point, so answering in whole tabs left it dead here.
  @Test func aHalfShownTabIsWhatItsOwnArrowFinishes() {
    #expect(target(.leading, at: 50) == 0, "half of tab 0 is cut off at the left")
    #expect(target(.trailing, at: 50) == 3, "and half of tab 3 at the right")
  }

  /// The pair that drew a chevron answering nothing: whatever end `Overflow`
  /// fades, `stepTarget` has somewhere to go.
  @Test func everyEndThatFadesCanBeSteppedFrom() {
    for offset in stride(from: 0.0, through: 400, by: 7) {
      let overflow = TabStripLayout.Overflow(offset: offset, viewport: 300, content: 700)
      #expect(
        overflow.hasTabsPastLeading == (target(.leading, at: offset) != nil),
        "at \(offset)",
      )
      #expect(
        overflow.hasTabsPastTrailing == (target(.trailing, at: offset) != nil),
        "at \(offset)",
      )
    }
  }

  @Test func theEndOfTheTravelOffersNothingFurther() {
    #expect(target(.trailing, at: 400) == nil, "tabs 4, 5 and 6 fill the view")
    #expect(target(.leading, at: 400) == 3)
  }

  @Test func aStripWithNothingInItOrNotYetScrolledIsAskedNothing() {
    #expect(layout.stepTarget(towards: .trailing, offset: 0, viewport: 300, count: 0) == nil)
    #expect(layout.stepTarget(towards: .trailing, offset: .nan, viewport: 300, count: 7) == nil)
    #expect(layout.stepTarget(towards: .leading, offset: -40, viewport: 300, count: 7) == nil)
    #expect(
      layout.stepTarget(towards: .trailing, offset: 0, viewport: 4000, count: 7) == nil,
      "every tab already in view",
    )
  }
}
