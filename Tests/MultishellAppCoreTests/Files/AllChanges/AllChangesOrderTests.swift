import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

struct AllChangesOrderTests {
  private static func change(_ path: String, _ kind: StatusChange.Kind = .modified) -> StatusChange
  {
    StatusChange(path: path, kind: kind, lines: .counted(insertions: 1, deletions: 1))
  }

  @Test func filesFollowTheChangesTreeFoldersFirstAndNamesAsFinderSortsThem() {
    let files = AllChangesOrder.files(
      of: ["z.txt", "file10.txt", "Sources/b.swift", "file2.txt", "Docs/a.md", "Sources/A/c.swift"]
        .map { Self.change($0) }
    )

    #expect(
      files.map(\.path) == [
        "Docs/a.md", "Sources/A/c.swift", "Sources/b.swift", "file2.txt", "file10.txt", "z.txt",
      ]
    )
  }

  @Test func aFileReplacedByAFolderOfItsNameListsTheFolderFirst() {
    let files = AllChangesOrder.files(of: [
      Self.change("x", .deleted), Self.change("x/y", .added),
    ])

    #expect(files.map(\.path) == ["x/y", "x"])
  }

  @Test func aPathListedTwiceIsOneFileCountedWholeAndANestedRepositoryIsLeftOut() {
    let files = AllChangesOrder.files(
      of: [
        StatusChange(path: "a.txt", kind: .deleted, lines: .counted(insertions: 0, deletions: 2)),
        StatusChange(path: "a.txt", kind: .added, lines: .counted(insertions: 2, deletions: 0)),
        StatusChange(path: "vendor/", kind: .added, lines: .notCounted),
      ]
    )

    #expect(files.count == 1)
    #expect(files.first?.kind == .added)
    #expect(files.first?.lineCounts == FileLineCounts(insertions: 2, deletions: 2))
  }
}
