import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite
struct FilesPanelFooterTextTests {
  private static func summary(
    _ comparison: ChangeComparison,
    tracked: TrackedFiles = .empty,
  ) -> FilesPanelSummary {
    FilesPanelSummary(
      tree: FileTree(
        FileTreeSources(tracked: tracked, status: nil, branchChanges: comparison.branchChanges)
      ),
      status: nil,
      comparison: comparison,
      tracked: tracked,
    )
  }

  @Test func whatThePanelLeftOutIsSaidAfterTheCountsAsASentenceOfItsOwn() {
    let tracked = TrackedFiles(
      paths: ["a.txt"],
      submodulePaths: [],
      notCheckedOutPaths: [],
      isCapped: true,
    )
    let summary = Self.summary(.head, tracked: tracked)

    #expect(FilesPanelFooterText.changes(summary) == "No modified files")
    #expect(FilesPanelFooterText.omissions(summary) == "Listing stops at 200000 tracked files.")
  }

  @Test func branchCountsItsChangesAndNamesTheBaseWhenThereAreNone() {
    let change = StatusChange(
      path: "a.txt",
      kind: .added,
      lines: .counted(insertions: 3, deletions: 0),
    )
    let changed = Self.summary(
      .branch(BranchChanges(baseName: "origin/main", mergeBase: "abc", changes: [change]))
    )
    let clean = Self.summary(
      .branch(BranchChanges(baseName: "origin/main", mergeBase: "abc", changes: []))
    )

    #expect(FilesPanelFooterText.changes(changed) == "1 changed file,")
    #expect(changed.insertions == 3)
    #expect(FilesPanelFooterText.changes(clean) == "No changes since origin/main")
  }

  @Test func branchWithNoBaseOrNoSharedHistorySaysWhichAndBeforeItsReadSaysNothing() {
    let unrelated = Self.summary(
      .branch(BranchChanges(baseName: "origin/main", mergeBase: nil, changes: []))
    )

    #expect(FilesPanelFooterText.changes(Self.summary(.noBase)) == "No base branch to compare with")
    #expect(FilesPanelFooterText.changes(unrelated) == "No history shared with origin/main")
    #expect(FilesPanelFooterText.changes(Self.summary(.unread)) == "")
  }

  @Test func anEmptyBranchListLeavesOutTheNewFilesTheStatusCouldNotList() {
    var status = WorktreeStatus()
    status.untracked = 3
    status.untrackedPaths = ["a.txt"]
    let unshared = BranchChanges(baseName: "origin/main", mergeBase: nil, changes: [])
    let summaries = [ChangeComparison.noBase, .unread, .branch(unshared)].map { comparison in
      FilesPanelSummary(
        tree: FileTree(FileTreeSources(status: status, branchChanges: [])),
        status: status,
        comparison: comparison,
        tracked: .empty,
      )
    }

    #expect(summaries.map(FilesPanelFooterText.omissions) == [nil, nil, nil])
  }
}
