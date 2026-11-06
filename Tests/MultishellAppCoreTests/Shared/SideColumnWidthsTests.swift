import Testing

@testable import MultishellAppCore

@Suite
struct SideColumnWidthsTests {
  private func widths(_ window: Double, _ sidebar: Double, _ panel: Double?) -> SideColumnWidths {
    SideColumnWidths(windowWidth: window, storedSidebar: sidebar, storedFilesPanel: panel)
  }

  @Test func sidesThatFitAreDrawnAsKept() {
    #expect(widths(1400, 248, 300) == SideColumnWidths(sidebar: 248, filesPanel: 300))
  }

  @Test func sidesBothPastHalfTheirRoomShareTheWindowInThirds() {
    #expect(widths(1200, 600, 500) == SideColumnWidths(sidebar: 400, filesPanel: 400))
  }

  @Test func aSideThatFitsKeepsItsWidthAndTheOtherTakesHalfWhatIsLeft() {
    #expect(widths(1200, 300, 900) == SideColumnWidths(sidebar: 300, filesPanel: 450))
    #expect(widths(1200, 900, 300) == SideColumnWidths(sidebar: 450, filesPanel: 300))
  }

  @Test func aShutPanelLeavesTheSidebarHalfTheWindow() {
    #expect(widths(1200, 900, nil) == SideColumnWidths(sidebar: 600, filesPanel: 0))
  }

  @Test func aWindowTooNarrowKeepsEachSidesMinimum() {
    let narrow = widths(300, 600, 600)

    #expect(narrow == SideColumnWidths(sidebar: SidebarWidth.minimum, filesPanel: 200))
  }
}
