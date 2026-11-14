import Testing

@testable import MultishellAppCore
@testable import MultishellCore

extension AllChangesDocumentTests {
  @Test func eachFilesTwoSidesLieRowForRowAndAFileOnlyAddedIsShownWholeYetHasItsRows() throws {
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
    #expect(committed.lines.map(\.text) == ["before 0", "old 0", "", "", ""])
    #expect(document.text.lines.map(\.text) == ["before 0", "new 0", "new 1", "new 0", "new 1"])
    #expect(document.sections.map(\.rows) == [0..<3, 3..<5])
    #expect(document.sections.map(\.isShownWhole) == [false, true])
    #expect(document.sections[1].fileText?.lines.map(\.text) == ["new 0", "new 1"])
    #expect([0, 1].map(document.showsSplitColumns(ofSection:)) == [true, false])
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
    #expect(fold == .fold(lines: 1...7))
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

  @Test func aFileShownWholeKeepsItsParsesSpansOnItsOwnRows() {
    let document = AllChangesDocument(
      .sample(rows: [("b.txt", .replacedBlock(before: 0, removed: 2, added: 0, after: 0))]),
      collapsed: [],
      heldOpen: [:],
      layout: .split,
    )
    let spans = [HighlightSpan(range: 4..<5, role: .keyword)]

    #expect(document.sliceSpans(spans, ofSection: 0) == spans)
  }
}
