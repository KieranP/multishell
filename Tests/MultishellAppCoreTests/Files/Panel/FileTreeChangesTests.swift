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

  @Test func aFolderNameStartingWithACombiningMarkStillSplitsAtTheSlashBeforeIt() {
    let path = "a/\u{0301}b/c.txt"
    let changes = FileTreeChanges([path], repositories: [])

    #expect(changes.foldersHoldingChanges == ["a", "a/\u{0301}b"])
    #expect(changes.roots.map(\.name) == ["a"])
    #expect(changes.roots.first?.children.map(\.name) == ["\u{0301}b"])
    #expect(changes.roots.first?.children.first?.children.map(\.path) == [path])
  }
}
