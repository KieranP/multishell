import MultishellGitKit
import Testing

@testable import MultishellAppCore

@Suite
struct AllChangesFileChangeLocationTests {
  @Test func aNameStartingWithACombiningMarkKeepsItsFolder() {
    let change = AllChangesFileChange(
      path: "docs/\u{301}notes.md",
      kind: .modified,
      lineCounts: nil,
    )

    #expect(change.folder == "docs")
    #expect(change.fileName == "\u{301}notes.md")
  }

  @Test func aFileAtTheRootHasNoFolder() {
    let change = AllChangesFileChange(path: "README.md", kind: .modified, lineCounts: nil)

    #expect(change.folder.isEmpty)
    #expect(change.fileName == "README.md")
  }
}
