import Testing

@testable import MultishellAppCore

/// Getting this wrong either hides that there is more, or offers an arrow at an end that
/// is already as far as it goes.
@Suite
struct TabStripLayoutEdgesTests {
  private func edges(_ offset: Double) -> TabStripLayout.Edges {
    TabStripLayout.Edges(offset: offset, viewport: 300, content: 700)
  }

  @Test func theEndItIsScrolledAwayFromHasMorePastIt() {
    // 700 points of tabs seen through 300, so the travel is 400.
    #expect(edges(200).hasTabsPastLeading, "200 points of tabs are off to the left")
    #expect(edges(200).hasTabsPastTrailing, "and 200 more off to the right")
  }

  @Test func eitherEndOfTheTravelSaysNothingIsFurtherThatWay() {
    #expect(!edges(0).hasTabsPastLeading, "as far left as it goes")
    #expect(edges(0).hasTabsPastTrailing)
    #expect(edges(400).hasTabsPastLeading)
    #expect(!edges(400).hasTabsPastTrailing, "as far right as it goes")
  }

  /// Rounding is what a strip scrolled to its end actually arrives at.
  @Test func aRoundingErrorIsNotMoreTabs() {
    #expect(!edges(0.4).hasTabsPastLeading)
    #expect(!edges(399.7).hasTabsPastTrailing)
  }

  @Test func aStripThatFitsOrHasNoUsableOffsetHasNothingPastAnEnd() {
    let fits = TabStripLayout.Edges(offset: 0, viewport: 500, content: 300)
    #expect(!fits.hasTabsPastLeading && !fits.hasTabsPastTrailing)
    let odd = TabStripLayout.Edges(offset: .nan, viewport: 300, content: 700)
    #expect(!odd.hasTabsPastLeading && !odd.hasTabsPastTrailing)
    let negative = TabStripLayout.Edges(offset: -20, viewport: 300, content: 700)
    #expect(!negative.hasTabsPastLeading, "rubber-banded past the leading edge")
  }
}
