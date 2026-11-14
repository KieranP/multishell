import MultishellCore
import Testing

@testable import MultishellAppCore

struct AllChangesDocumentChangedLinesTests {
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
    from start: AllChangesSteps.Stop?,
  ) -> AllChangesSteps.Stop? {
    document.changedLine(direction, from: start, slice: document.slice(ofSection:))
  }

  @Test func inSplitARemovedLineBesideNoAddedOneIsAChangedLine() {
    let split = AllChangesDocument(
      .sample(rows: [("a.txt", .replacedBlock(before: 1, removed: 2, added: 1, after: 1))]),
      collapsed: [],
      heldOpen: [:],
      layout: .split,
    )

    let next = split.changedLine(
      .next,
      from: AllChangesSteps.Stop(section: 0, row: 1),
      slice: split.slice(ofSection:),
    )

    #expect(next == AllChangesSteps.Stop(section: 0, row: 2))
  }

  @Test func fromNowhereNextIsTheFirstFilesFirstChangeAndPreviousTheLastFilesLast() {
    #expect(Self.line(.next, from: nil) == AllChangesSteps.Stop(section: 0, row: 1))
    #expect(Self.line(.previous, from: nil) == AllChangesSteps.Stop(section: 2, row: 1))
  }

  @Test func pastAFilesLastChangeTheWalkGoesOnInTheNextFileWithChangesShown() {
    let next = Self.line(.next, from: AllChangesSteps.Stop(section: 0, row: 2))
    let back = Self.line(.previous, from: AllChangesSteps.Stop(section: 2, row: 0))

    #expect(next == AllChangesSteps.Stop(section: 2, row: 0))
    #expect(back == AllChangesSteps.Stop(section: 0, row: 2))
  }

  @Test func theWalkStopsAtTheLastChangeOfTheLastFile() {
    #expect(Self.line(.next, from: AllChangesSteps.Stop(section: 2, row: 1)) == nil)
  }
}
