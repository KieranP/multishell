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
}
