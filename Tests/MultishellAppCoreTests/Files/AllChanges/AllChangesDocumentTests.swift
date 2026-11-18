import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit

struct AllChangesDocumentTests {
  private static func document(
    _ reading: AllChangesReading,
    collapsed: Set<String> = [],
    heldOpen: [String: [AllChangesLineSpan]] = [:],
  ) -> AllChangesDocument {
    AllChangesDocument(reading, collapsed: collapsed, heldOpen: heldOpen)
  }

  @Test func eachFilesRowsFollowTheLastFilesEndToEnd() {
    let document = Self.document(
      .sample(rows: [
        ("a.txt", .replacedBlock(before: 1, removed: 1, added: 1, after: 1)),
        ("b.txt", .replacedBlock(before: 0, removed: 0, added: 2, after: 0)),
      ])
    )

    #expect(
      document.text.lines.map(\.text) == [
        "before 0", "old 0", "new 0", "after 0", "new 0", "new 1",
      ]
    )
    #expect(document.sections.map(\.rows) == [0..<4, 4..<6])
    #expect(document.gapItems.isEmpty)
    #expect(document.section(atRow: 3) == 0 && document.section(atRow: 4) == 1)
  }

  @Test func aFileStillToBeReadIsAChangeTheArrowsCanStepTo() {
    let document = Self.document(.sample([("a.txt", .unread)]))

    #expect(document.hasChanges)
  }

  @Test func aFileKeptStaleCountsAsTheChangesListDoesNotAsItsOldRows() throws {
    let read = AllChangesReading.sample(rows: [
      ("a.txt", .replacedBlock(before: 0, removed: 1, added: 1, after: 0))
    ])
    let old = try #require(read.files.first)
    let listed = AllChangesFileChange(
      path: "a.txt",
      kind: .modified,
      lineCounts: FileLineCounts(insertions: 7, deletions: 2),
    )
    let stale = AllChangesFile(
      change: listed,
      content: old.content,
      signature: nil,
      isStale: true,
    )

    let document = Self.document(AllChangesReading(listed: [listed], files: [stale]))

    #expect(document.sections.first?.lineCounts == listed.lineCounts)
    #expect(document.lineCounts == listed.lineCounts)
  }

  @Test func anUnchangedRunPastThreeLinesOfContextFoldsAndAShortOneShowsWhole() {
    let rows = FileTabRows.replacedBlock(before: 10, removed: 1, added: 1, after: 5)

    let document = Self.document(.sample(rows: [("a.txt", rows)]))

    #expect(document.text.lines.first?.text == "before 7")
    #expect(document.text.lines.count == 3 + 2 + 5)
    #expect(
      document.gapItems.last
        == AllChangesGapItem(afterRow: -1, section: 0, kind: .fold(lines: 1...7))
    )
  }

  @Test func linesHeldOpenStayOutOfTheirFold() {
    let rows = FileTabRows.replacedBlock(before: 20, removed: 1, added: 1, after: 0)

    let document = Self.document(
      .sample(rows: [("a.txt", rows)]),
      heldOpen: ["a.txt": [AllChangesLineSpan(side: .onDisk, lines: 8...12)]],
    )

    let folds = document.gapItems.compactMap { item -> ClosedRange<Int>? in
      if case .fold(let lines) = item.kind { lines } else { nil }
    }
    #expect(folds == [1...7, 13...17])
    #expect(document.text.lines.prefix(5).compactMap(\.newNumber) == [8, 9, 10, 11, 12])
  }

  @Test func aCollapsedFileShowsItsHeaderAloneAndAFileWithoutRowsItsNotice() {
    let document = Self.document(
      .sample([
        (
          "a.txt",
          .read(
            FileTabReading(
              content: .text(.replacedBlock(before: 0, removed: 1, added: 1, after: 0)),
              isFileGone: false,
            )
          ),
        ),
        ("b.bin", .read(FileTabReading(content: .binary(bytes: 9), isFileGone: false))),
        ("c.txt", .pastRowCap),
      ]),
      collapsed: ["a.txt"],
    )

    #expect(document.text.lines.isEmpty)
    #expect(document.sections.map(\.isCollapsed) == [true, false, false])
    #expect(
      document.gapItems.map(\.kind) == [
        .notice(.binary(bytes: 9)), .notice(.pastRowCap),
      ]
    )
  }

  @Test func aChangeEndingOneFileAndOneStartingTheNextAreTwoSteps() {
    let document = Self.document(
      .sample(rows: [
        ("a.txt", .replacedBlock(before: 0, removed: 0, added: 1, after: 0)),
        ("b.txt", .replacedBlock(before: 0, removed: 1, added: 0, after: 0)),
      ])
    )

    #expect(document.text.changeStarts == [0, 1])
    #expect(document.text.change(containing: 0) == 0..<1)
  }

  @Test func aScrollIsHeldByItsFileAndLineSoAFoldOpeningAboveKeepsIt() throws {
    let reading = AllChangesReading.sample(rows: [
      ("a.txt", .replacedBlock(before: 1, removed: 1, added: 1, after: 0)),
      ("b.txt", .replacedBlock(before: 20, removed: 1, added: 1, after: 0)),
    ])
    let folded = Self.document(reading)
    let scroll = try #require(
      folded.scroll(atRow: Double(folded.sections[1].rows.lowerBound + 1), x: 0)
    )

    let opened = Self.document(
      reading,
      heldOpen: ["b.txt": [AllChangesLineSpan(side: .onDisk, lines: 1...20)]],
    )

    let row = try #require(opened.row(of: scroll))
    #expect(scroll.path == "b.txt")
    #expect(
      opened.text.lines[Int(row)].text
        == folded.text.lines[folded.sections[1].rows.lowerBound + 1].text
    )
  }

  @Test func aFilesSpansLandOnTheRowsShownOfItAndAFoldedRowsAreLeftOut() {
    let rows = FileTabRows.replacedBlock(before: 10, removed: 0, added: 1, after: 0)
    let document = AllChangesDocument(
      .sample(rows: [
        ("a.txt", .replacedBlock(before: 0, removed: 0, added: 1, after: 0)), ("b.txt", rows),
      ]),
      collapsed: [],
      heldOpen: [:],
    )
    let fileText = rows.displayText
    let folded = fileText.range(ofRow: 0)
    let shown = fileText.range(ofRow: 10)

    let spans = document.documentSpans(
      [HighlightSpan(range: folded, role: .keyword), HighlightSpan(range: shown, role: .string)],
      ofSection: 1,
    )

    let row = document.sections[1].documentRow(ofFileRow: 10)
    #expect(spans == [HighlightSpan(range: document.text.range(ofRow: row ?? -1), role: .string)])
  }
}
