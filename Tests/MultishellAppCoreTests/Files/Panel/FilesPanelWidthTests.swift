import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct FilesPanelWidthTests {
  @Test func thePanelTakesAtMostHalfTheDetailArea() {
    #expect(FilesPanelWidth.range(inDetailOfWidth: 2000) == 200...1000)
    #expect(FilesPanelWidth.range(inDetailOfWidth: 600) == 200...300)
    #expect(FilesPanelWidth.range(inDetailOfWidth: 100) == 200...200)
  }

  @Test func aDragToTheLeftWidensThePanel() {
    let range = 200.0...900.0
    #expect(FilesPanelWidth.dragged(from: 280, by: -40, in: range) == 320)
    #expect(FilesPanelWidth.dragged(from: 280, by: 900, in: range) == 200)
  }
}
