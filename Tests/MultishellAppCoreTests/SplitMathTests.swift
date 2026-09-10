import Testing

@testable import MultishellAppCore

/// Divider drags write straight into the persisted pane tree, so a wrong
/// number here is saved and shown on every launch.
@Suite
struct SplitMathTests {
  private func drag(
    _ translation: Double, weights: [Double], available: Double = 600, index: Int = 0
  ) -> [Double] {
    SplitMath.transferring(
      translation, acrossDividerAfter: index, in: weights, available: available, minimumPane: 80)
  }

  @Test func movingTheDividerTradesWeightBetweenItsTwoPanesOnly() {
    // 600 points shared 1:1:1 is 200 each; 100 points is half a weight.
    let after = drag(100, weights: [1, 1, 1])
    #expect(after == [1.5, 0.5, 1])
    #expect(after.reduce(0, +) == 3)
  }

  @Test func neitherPaneGoesBelowTheMinimum() {
    // 80 points of 600 is 0.4 of a weight.
    #expect(close(drag(1000, weights: [1, 1, 1]), to: [1.6, 0.4, 1]))
    #expect(close(drag(-1000, weights: [1, 1, 1]), to: [0.4, 1.6, 1]))
  }

  /// What a drop that would make a new tab group asks first. 6 points of
  /// divider and 80 a pane, so 166 fits and 165 does not.
  @Test func aLengthTooShortToHalveIsRefused() {
    #expect(SplitMath.canHalve(166, minimumPane: 80, divider: 6))
    #expect(!SplitMath.canHalve(165, minimumPane: 80, divider: 6))
    #expect(!SplitMath.canHalve(0, minimumPane: 80, divider: 6))
    #expect(!SplitMath.canHalve(.nan, minimumPane: 80, divider: 6), "a width not yet measured")
  }

  private func close(_ a: [Double], to b: [Double]) -> Bool {
    a.count == b.count && zip(a, b).allSatisfy { abs($0 - $1) < 1e-9 }
  }

  @Test func twoPanesTooSmallForTheMinimumSplitEvenlyInsteadOfGoingNegative() {
    // Fourteen panes in 600 points are 43 each; the old clamp made the
    // second share negative, and that was written to disk.
    let weights = Array(repeating: 1.0, count: 14)
    let after = drag(500, weights: weights)
    #expect(after.allSatisfy { $0 >= 0 })
    #expect(after[0] == 1 && after[1] == 1, "no room to move, so nothing moves")
  }

  @Test func invalidInputIsReturnedUnchanged() {
    #expect(drag(50, weights: [1, 1], index: 1) == [1, 1], "no pane after the last divider")
    #expect(drag(50, weights: [1, 1], index: -1) == [1, 1])
    #expect(drag(50, weights: [1, 1], available: 0) == [1, 1])
    #expect(drag(50, weights: [0, 0]) == [0, 0])
    #expect(drag(50, weights: [1]) == [1])
  }

  @Test func aDragOnAnInnerDividerLeavesTheOthersAlone() {
    let after = drag(60, weights: [2, 1, 1], index: 1)
    #expect(after[0] == 2)
    #expect(after[1] + after[2] == 2)
    #expect(after[1] > 1)
  }
}
