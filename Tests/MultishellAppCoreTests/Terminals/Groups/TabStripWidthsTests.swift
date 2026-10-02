import Testing

@testable import MultishellAppCore

@Suite
struct TabStripWidthsTests {
  private let widths = TabStripWidths(buttons: 90, newTabMenu: 30, arrow: 20, minimumTab: 100)

  @Test func theSplitsShowOnceTheyCostNeitherATabNorTheArrows() {
    #expect(widths.showsSplits(in: 230))
    #expect(!widths.showsSplits(in: 229))
    #expect(!widths.showsSplits(in: .infinity))
  }

  @Test func theTabsHaveWhatTheButtonsShownLeave() {
    #expect(widths.tabsAvailable(in: 230) == 140)
    #expect(widths.tabsAvailable(in: 229) == 199)
  }

  @Test func aScrollingStripHasGuttersOnlyWithRoomForBothArrowsAndATab() {
    #expect(widths.arrowGutter(forAvailable: 140) == 20)
    #expect(widths.arrowGutter(forAvailable: 139) == 0)
  }

  @Test func aScrollingStripsViewportIsWhatItsGuttersLeave() {
    #expect(widths.scrollingViewport(forAvailable: 140) == 100)
    #expect(widths.scrollingViewport(forAvailable: 139) == 139)
  }
}
