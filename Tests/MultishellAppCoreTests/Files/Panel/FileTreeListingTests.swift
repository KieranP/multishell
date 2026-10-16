import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite
struct FileTreeListingTests {
  private static func sources(_ changes: [StatusChange]) -> FileTreeSources {
    var status = WorktreeStatus()
    status.setChanges(changes)
    return FileTreeSources(
      tracked: TrackedFiles(
        paths: ["a.txt", "b.txt"],
        submodulePaths: [],
        notCheckedOutPaths: [],
        isCapped: false,
      ),
      status: status,
    )
  }

  @Test func aTrackedFileFirstModifiedKeepsTheListingAndOneDeletedMovesIt() {
    let clean = FileTreeListing.Key(Self.sources([]))
    let lines = StatusChange.Lines.counted(insertions: 1, deletions: 0)

    let modified = FileTreeListing.Key(
      Self.sources([StatusChange(path: "a.txt", kind: .modified, lines: lines)])
    )
    let deleted = FileTreeListing.Key(
      Self.sources([StatusChange(path: "gone.txt", kind: .deleted, lines: lines)])
    )

    #expect(modified == clean)
    #expect(deleted != clean)
  }

  @Test func aModifiedFilePastTheTrackedCapStillLists() {
    var status = WorktreeStatus()
    status.setChanges([
      StatusChange(
        path: "past-cap.txt",
        kind: .modified,
        lines: .counted(insertions: 1, deletions: 0),
      )
    ])
    let sources = FileTreeSources(
      tracked: TrackedFiles(
        paths: ["a.txt"],
        submodulePaths: [],
        notCheckedOutPaths: [],
        isCapped: true,
      ),
      status: status,
    )

    let listing = FileTreeListing(sources, key: FileTreeListing.Key(sources))

    #expect(listing.filePaths == ["a.txt", "past-cap.txt"])
  }
}
