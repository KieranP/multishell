import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct DiffDisplayTextScrollAnchorTests {
  private static let rows = FileTabRows.replacedBlock(
    before: 0,
    removed: 100,
    added: 100,
    after: 400,
  )

  @Test func aScrollTakenInUnifiedPutsTheSameLineAtTheTopOfSplit() throws {
    let unified = Self.rows.displayText
    let split = try #require(Self.rows.split).onDisk

    let scroll = unified.scroll(atRow: 300.25, x: 8)
    let row = split.row(of: scroll)

    #expect(scroll.line == 201)
    #expect(split.lines[Int(row)].newNumber == 201)
    #expect(row - row.rounded(.down) == 0.25)
  }

  @Test func aScrollOnARemovedRowIsHeldByHEADsLine() {
    let unified = Self.rows.displayText

    let scroll = unified.scroll(atRow: 40, x: 0)

    #expect(scroll == FileTabScroll(line: 41, isCommittedLine: true, rowsFromLine: 0, x: 0))
    #expect(unified.row(of: scroll) == 40)
  }

  @Test func aDeletedFilesScrollIsHeldByHEADsLine() {
    let deleted = DiffDisplayText(
      (0..<50).map { index in
        DiffLine(kind: .removed, oldNumber: index + 1, newNumber: nil, text: "\(index)")
      },
      marksStaging: true,
    )

    let scroll = deleted.scroll(atRow: 20, x: 0)

    #expect(scroll == FileTabScroll(line: 21, isCommittedLine: true, rowsFromLine: 0, x: 0))
    #expect(deleted.row(of: scroll) == 20)
  }

  @Test func aTopRowOnlyHEADHasIsHeldByHEADsLineAndFoundOnSplitsLeft() throws {
    let rows = FileTabRows.replacedBlock(before: 200, removed: 100, added: 100, after: 0)
    let unified = rows.displayText
    let split = try #require(rows.split).committed

    let scroll = unified.scroll(atRow: 250, x: 0)

    #expect(scroll.isCommittedLine)
    #expect(split.lines[Int(split.row(of: scroll))].oldNumber == 251)
  }

  @Test func aLineOnDiskRestoredOntoAFileNowDeletedLandsOnHEADsLineOfThatNumber() {
    let onDisk = DiffDisplayText(
      (0..<300).map { index in
        DiffLine(kind: .context, oldNumber: index + 1, newNumber: index + 1, text: "\(index)")
      },
      marksStaging: true,
    )
    let deleted = DiffDisplayText(
      (0..<300).map { index in
        DiffLine(kind: .removed, oldNumber: index + 1, newNumber: nil, text: "\(index)")
      },
      marksStaging: true,
    )

    let scroll = onDisk.scroll(atRow: 50, x: 0)

    #expect(deleted.row(of: scroll) == 50)
  }
}
