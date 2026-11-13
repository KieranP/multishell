import Testing

@testable import MultishellAppCore

@Suite
struct FileTreeRowPendingCommentsTests {
  private static func row(isFolder: Bool) -> FileTreeRow {
    FileTreeRow(
      path: "docs",
      name: "docs",
      parentFolder: nil,
      depth: 0,
      isFolder: isFolder,
      isExpanded: false,
      holdsChange: false,
      changeKind: nil,
      lineCounts: nil,
      isRepository: false,
      isIgnored: false,
      isOpenable: true,
    )
  }

  @Test func aFolderAtAReplacedFilesPathTakesNoneOfTheFilesComments() {
    let counts = ["docs": 2]

    #expect(Self.row(isFolder: false).pendingComments(in: counts) == 2)
    #expect(Self.row(isFolder: true).pendingComments(in: counts) == 0)
  }
}
