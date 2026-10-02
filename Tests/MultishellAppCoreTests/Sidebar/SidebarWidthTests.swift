import Testing

@testable import MultishellAppCore

@Suite
struct SidebarWidthTests {
  @Test func theSidebarLeavesTheDetailItsMinimum() {
    let range = SidebarWidth.range(inWindowOfWidth: 1000)
    #expect(range.lowerBound == SidebarWidth.minimum)
    #expect(range.upperBound == 1000 - SidebarWidth.minimumDetail)
  }

  @Test func aWindowTooNarrowForBothKeepsTheSidebarsMinimum() {
    let range = SidebarWidth.range(inWindowOfWidth: SidebarWidth.minimum)
    #expect(range == SidebarWidth.minimum...SidebarWidth.minimum)
  }

  @Test func aDragMovesTheWidthByItsTravelAndStopsAtEitherEnd() {
    let range = 200.0...600.0
    #expect(SidebarWidth.dragged(from: 300, by: 50, in: range) == 350)
    #expect(SidebarWidth.dragged(from: 300, by: 900, in: range) == 600)
    #expect(SidebarWidth.dragged(from: 300, by: -900, in: range) == 200)
  }

  @Test func aDragFromAWidthTheWindowNoLongerHoldsStartsFromItsEdge() {
    #expect(SidebarWidth.dragged(from: 900, by: -50, in: 200.0...600.0) == 550)
  }
}
