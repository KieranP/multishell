import Testing

@testable import MultishellAppCore

struct AllChangesDocumentStopsTests {
  @Test func eachChangeIsAStopAndAFileStillToBeReadOneAtItsTop() {
    let document = AllChangesDocument(
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
      ]),
      collapsed: [],
      heldOpen: [:],
    )

    #expect(document.unreadSections == [1])
    #expect(
      document.changeStops == [
        AllChangesFileRow(section: 0, row: 1), AllChangesFileRow(section: 1, row: 0),
      ]
    )
  }
}
