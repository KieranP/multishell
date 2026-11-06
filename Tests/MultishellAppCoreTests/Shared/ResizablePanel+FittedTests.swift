import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite
struct ResizablePanelFittedTests {
  @Test func aFittedColumnRoundsItsRowsUpSoNoFractionTruncatesOne() {
    #expect(ResizablePanel.fitted(312.2, in: 200...900) == 313)
  }

  @Test func aFittedColumnIsNeverNarrowerThanADragAllows() {
    #expect(ResizablePanel.fitted(90, in: 200...900) == 200)
  }

  @Test func aFittedColumnIsNeverWiderThanADragAllows() {
    #expect(ResizablePanel.fitted(1400, in: 200...900) == 900)
  }
}
