import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct SplitDiffScrollAnchorTests {
  @Test func aSplitScrollOverPaddingIsHeldByTheLineHEADHasThere() throws {
    let rows = FileTabRows.replacedBlock(before: 50, removed: 100, added: 20, after: 200)
    let split = try #require(rows.split)

    let scroll = split.scroll(atRow: 100, x: 0)

    let unifiedRow = Int(rows.displayText.row(of: scroll))
    #expect(rows.displayText.lines[unifiedRow].oldNumber == split.committed.lines[100].oldNumber)
  }

  @Test func unifiedToSplitAndBackReturnsToTheSameRow() throws {
    let rows = FileTabRows.replacedBlock(before: 50, removed: 100, added: 100, after: 200)
    let split = try #require(rows.split)
    let unified = rows.displayText

    let splitRow = split.committed.row(of: unified.scroll(atRow: 100, x: 0))
    let back = unified.row(of: split.scroll(atRow: splitRow, x: 0))

    #expect(back == 100)
  }
}
