import Testing

@testable import MultishellAppUI

@Suite
struct TerminalCellWidthTests {
  @Test func wideCharactersAndEmojiTakeTwoCellsAndTheRestOne() {
    #expect(TerminalCellWidth.cells(of: "a") == 1)
    #expect(TerminalCellWidth.cells(of: "é") == 1)
    #expect(TerminalCellWidth.cells(of: "日") == 2)
    #expect(TerminalCellWidth.cells(of: "가") == 2)
    #expect(TerminalCellWidth.cells(of: "😀") == 2)
    #expect(TerminalCellWidth.cells(of: "👨‍👩‍👧") == 2)
    #expect(TerminalCellWidth.cells(of: "❤️") == 2)
  }
}
