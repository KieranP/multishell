import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite
struct AllChangesDocumentSplitTests {
  @Test func eachFilesTwoSidesLieRowForRowAndAFileOnlyAddedIsShownWholeAcrossBoth() throws {
    let document = AllChangesDocument(
      .sample(rows: [
        ("a.txt", .replacedBlock(before: 1, removed: 1, added: 2, after: 0)),
        ("b.txt", .replacedBlock(before: 0, removed: 0, added: 2, after: 0)),
      ]),
      collapsed: [],
      heldOpen: [:],
      layout: .split,
    )

    let committed = try #require(document.committedText)
    #expect(committed.lines.map(\.text) == ["before 0", "old 0", ""])
    #expect(document.text.lines.map(\.text) == ["before 0", "new 0", "new 1"])
    #expect(document.sections.map(\.rows) == [0..<3, 3..<3])
    #expect(document.sections.map(\.isShownWhole) == [false, true])
    #expect(document.gapItems.last == AllChangesGapItem(afterRow: 2, section: 1, kind: .wholeFile))
    #expect(document.sections[1].fileText?.lines.map(\.text) == ["new 0", "new 1"])
  }

  @Test func aSplitFoldsOnlyRowsUnchangedOnBothSides() throws {
    let document = AllChangesDocument(
      .sample(rows: [("a.txt", .replacedBlock(before: 10, removed: 2, added: 1, after: 0))]),
      collapsed: [],
      heldOpen: [:],
      layout: .split,
    )

    let committed = try #require(document.committedText)
    #expect(document.text.lines.count == committed.lines.count)
    #expect(committed.lines.map(\.text) == ["before 7", "before 8", "before 9", "old 0", "old 1"])
    #expect(document.text.lines.map(\.text) == ["before 7", "before 8", "before 9", "new 0", ""])
    let fold = document.gapItems.last?.kind
    #expect(fold == .fold(fileRows: 0..<7, lines: 1...7))
  }

  @Test func aRemovedLinesCommentGoesInTheLeftColumnOnItsFilesRow() throws {
    let document = AllChangesDocument(
      .sample(rows: [("a.txt", .replacedBlock(before: 1, removed: 1, added: 1, after: 0))]),
      collapsed: [],
      heldOpen: [:],
      layout: .split,
    )

    let left = document.lineSelection(from: 1, to: 1, side: .committed)
    let right = document.lineSelection(from: 1, to: 1, side: .onDisk)

    #expect(
      left?.selection
        == ReviewLineSelection(
          from: 1,
          to: 1,
          in: document.committedText?.lines ?? [],
          side: .committed,
        )
    )
    #expect(left?.selection.side == .committed && right?.selection.side == .onDisk)
    #expect(left?.selection.lines == 2...2 && right?.selection.lines == 2...2)
  }
}
