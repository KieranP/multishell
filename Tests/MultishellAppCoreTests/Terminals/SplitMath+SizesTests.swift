import Testing

@testable import MultishellAppCore

@Suite
struct SplitMathSizesTests {
  @Test func eachDividerComesOffTheLengthBeforeItIsShared() {
    #expect(SplitMath.available(606, panes: 2, divider: 6) == 600)
    #expect(SplitMath.available(612, panes: 3, divider: 6) == 600)
    #expect(SplitMath.available(600, panes: 1, divider: 6) == 600)
  }

  @Test func aLengthShorterThanItsDividersLeavesNothing() {
    #expect(SplitMath.available(4, panes: 3, divider: 6) == 0)
  }

  @Test func panesShareTheLengthByWeight() {
    #expect(SplitMath.sizes(of: [1, 3], sharing: 600) == [150, 450])
    #expect(SplitMath.sizes(of: [2, 2, 2], sharing: 600) == [200, 200, 200])
  }

  @Test func weightsSummingToNothingShareEvenly() {
    #expect(SplitMath.sizes(of: [0, 0], sharing: 600) == [300, 300])
  }

  @Test func noPanesHaveNoSizes() {
    #expect(SplitMath.sizes(of: [], sharing: 600).isEmpty)
  }
}
