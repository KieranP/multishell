import Testing

@testable import MultishellAppCore

/// Getting this wrong either hides that there is more, or offers an arrow at an end that
/// is already as far as it goes.
extension TabStripLayoutTests {
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
