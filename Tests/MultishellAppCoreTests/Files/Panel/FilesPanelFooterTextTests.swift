import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite
struct FilesPanelFooterTextTests {
  @Test func whatThePanelLeftOutIsSaidAfterTheCountsAsASentenceOfItsOwn() {
    let tracked = TrackedFiles(
      paths: ["a.txt"],
      submodulePaths: [],
      notCheckedOutPaths: [],
      isCapped: true,
    )
    let summary = FilesPanelSummary(
      tree: FileTree(FileTreeSources(tracked: tracked, status: nil)),
      status: nil,
      tracked: tracked,
    )

    #expect(FilesPanelFooterText.changes(summary) == "No modified files")
    #expect(FilesPanelFooterText.omissions(summary) == "Listing stops at 200000 tracked files.")
  }
}
