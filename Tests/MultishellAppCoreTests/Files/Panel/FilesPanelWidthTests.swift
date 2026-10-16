import Testing

@testable import MultishellAppCore

@Suite
struct FilesPanelWidthTests {
  @Test func thePanelRunsFromItsMinimumToItsMaximumLeavingTheTabsTheirs() {
    #expect(FilesPanelWidth.range(inDetailOfWidth: 2000) == 200...560)
    #expect(FilesPanelWidth.range(inDetailOfWidth: 400) == 200...(400 - TabAreaWidth.minimum))
    #expect(FilesPanelWidth.range(inDetailOfWidth: 100) == 200...200)
  }

  @Test func aDragToTheLeftWidensThePanel() {
    let range = 200.0...560.0
    #expect(FilesPanelWidth.dragged(from: 280, by: -40, in: range) == 320)
    #expect(FilesPanelWidth.dragged(from: 280, by: 900, in: range) == 200)
  }
}
