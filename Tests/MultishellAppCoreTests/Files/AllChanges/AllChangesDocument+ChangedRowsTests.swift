import MultishellCore
import Testing

@testable import MultishellAppCore

struct AllChangesDocumentChangedRowsTests {
  private static let document = AllChangesDocument(
    .sample([
      (
        "a.txt",
        .read(
          FileTabReading(
            content: .text(.replacedBlock(before: 1, removed: 1, added: 1, after: 1)),
            isFileGone: false,
          )
        ),
      ),
      ("b.txt", .unread),
      (
        "c.txt",
        .read(
          FileTabReading(
            content: .text(.replacedBlock(before: 0, removed: 0, added: 2, after: 0)),
            isFileGone: false,
          )
        ),
      ),
    ]),
    collapsed: [],
    heldOpen: [:],
  )

  private static func line(
    _ direction: CycleDirection,
    from start: AllChangesFileRow?,
  ) -> AllChangesFileRow? {
    document.changedRow(direction, from: start, slice: document.slice(ofSection:))
  }

  @Test func inSplitARemovedLineBesideNoAddedOneIsAChangedLine() {
    let split = AllChangesDocument(
      .sample(rows: [("a.txt", .replacedBlock(before: 1, removed: 2, added: 1, after: 1))]),
      collapsed: [],
      heldOpen: [:],
      layout: .split,
    )

    let next = split.changedRow(
      .next,
      from: AllChangesFileRow(section: 0, row: 1),
      slice: split.slice(ofSection:),
    )

    #expect(next == AllChangesFileRow(section: 0, row: 2))
  }

  @Test func fromNowhereNextIsTheFirstFilesFirstChangeAndPreviousTheLastFilesLast() {
    #expect(Self.line(.next, from: nil) == AllChangesFileRow(section: 0, row: 1))
    #expect(Self.line(.previous, from: nil) == AllChangesFileRow(section: 2, row: 1))
  }

  @Test func pastAFilesLastChangeTheWalkGoesOnInTheNextFileWithChangesShown() {
    let next = Self.line(.next, from: AllChangesFileRow(section: 0, row: 2))
    let back = Self.line(.previous, from: AllChangesFileRow(section: 2, row: 0))

    #expect(next == AllChangesFileRow(section: 2, row: 0))
    #expect(back == AllChangesFileRow(section: 0, row: 2))
  }

  @Test func theWalkStopsAtTheLastChangeOfTheLastFile() {
    #expect(Self.line(.next, from: AllChangesFileRow(section: 2, row: 1)) == nil)
  }
}
