import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite
struct AllChangesDocumentFileSliceTests {
  @Test func aFilesSliceHoldsItsOwnShownRowsAndItsFoldsByThoseRows() {
    let document = AllChangesDocument(
      .sample(rows: [
        ("a.txt", .replacedBlock(before: 1, removed: 1, added: 1, after: 1)),
        ("b.txt", .replacedBlock(before: 10, removed: 1, added: 1, after: 0)),
      ]),
      collapsed: [],
      heldOpen: [:],
    )

    let slice = document.slice(ofSection: 1)

    #expect(
      slice.text.lines.map(\.text) == ["before 7", "before 8", "before 9", "old 0", "new 0"]
    )
    #expect(
      slice.gapItems
        == [
          AllChangesGapItem(afterRow: -1, section: 1, kind: .fold(lines: 1...7))
        ]
    )
  }

  @Test func aLineCutForDisplayInAFilesSliceStillCopiesWhole() {
    let long = String(repeating: "x", count: 10_000) + "tail"
    let document = AllChangesDocument(
      .sample(rows: [
        (
          "a.txt",
          FileTabRows(
            lines: [DiffLine(kind: .added, oldNumber: nil, newNumber: 1, text: long)],
            marksStaging: true,
          ),
        )
      ]),
      collapsed: [],
      heldOpen: [:],
    )

    let slice = document.slice(ofSection: 0)

    #expect(slice.text.uncutText(ofRow: 0) == long)
  }

  @Test func aFoldOpeningLeavesTheSlicesCommittedSideAsItWas() {
    let reading = AllChangesReading.sample(rows: [
      ("a.txt", .replacedBlock(before: 20, removed: 1, added: 1, after: 0))
    ])
    let folded = AllChangesDocument(reading, collapsed: [], heldOpen: [:])
    let opened = AllChangesDocument(
      reading,
      collapsed: [],
      heldOpen: ["a.txt": [AllChangesLineSpan(side: .onDisk, lines: 1...17)]],
    )

    #expect(
      folded.slice(ofSection: 0).text.committedDigest
        == opened.slice(ofSection: 0).text.committedDigest
    )
  }
}
