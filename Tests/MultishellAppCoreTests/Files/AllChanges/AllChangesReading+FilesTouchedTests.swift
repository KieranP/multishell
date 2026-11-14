import Testing

@testable import MultishellAppCore

struct AllChangesReadingFilesTouchedTests {
  private static let rows = FileTabRows(lines: [], marksStaging: true)

  @Test func anEventOnAFileOrItsFolderTouchesItAndOnAnotherFolderDoesNot() {
    let reading = AllChangesReading.sample(rows: [
      ("a.txt", Self.rows), ("docs/b.txt", Self.rows), ("src/c.txt", Self.rows),
    ])

    let touched = reading.filesTouched(by: ["a.txt", "docs", "other"])

    #expect(touched.map(\.path) == ["a.txt", "docs/b.txt"])
  }

  @Test func anEventOnAFileStillToBeReadTouchesNothing() {
    let reading = AllChangesReading.sample([("a.txt", .unread)])

    #expect(reading.filesTouched(by: ["a.txt", ""]).isEmpty)
  }

  @Test func anEventOnAFilePastTheRowCapOrAnImageTouchesNothing() {
    let reading = AllChangesReading.sample([("a.txt", .pastRowCap), ("b.png", .image)])

    #expect(reading.filesTouched(by: ["a.txt", "b.png"]).isEmpty)
  }

  @Test func anEventOnAFileAlreadyKeptStaleTouchesNothing() {
    let read = AllChangesReading.sample(rows: [("a.txt", Self.rows)])
    var stale = read.files[0]
    stale.isStale = true
    let reading = AllChangesReading(listed: read.listed, files: [stale])

    #expect(reading.filesTouched(by: ["a.txt"]).isEmpty)
  }

  @Test func aGitChangeInAnEmbeddedRepositoryTouchesTheFilesInsideItAlone() {
    let reading = AllChangesReading.sample(rows: [
      ("a.txt", Self.rows), ("vendor/lib/x.c", Self.rows), ("vendor/other.c", Self.rows),
    ])

    #expect(reading.paths(inRepositories: ["vendor/lib"]) == ["vendor/lib/x.c"])
  }
}
