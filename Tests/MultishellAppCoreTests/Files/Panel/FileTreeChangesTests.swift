import Testing

@testable import MultishellAppCore

@Suite
struct FileTreeChangesTests {
  @Test func everyFolderAboveAChangeHoldsIt() {
    let changes = FileTreeChanges(["a/b/c.txt", "a/d.txt", "e.txt"], repositories: [])

    #expect(changes.foldersHoldingChanges == ["a", "a/b"])
  }

  @Test func aFolderGitListsWithItsSlashHoldsNoChangeOfItsOwn() {
    let changes = FileTreeChanges(["a/new/"], repositories: [])

    #expect(changes.foldersHoldingChanges == ["a"])
  }
}
