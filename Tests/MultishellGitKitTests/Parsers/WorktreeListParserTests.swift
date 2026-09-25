import Foundation
import MultishellCore
import Testing

@testable import MultishellGitKit

@Suite
struct WorktreeListParserTests {
  private let porcelain = """
    worktree /Users/dev/Work/multishell
    HEAD 8f3c21a9c0d4e1f2a3b4c5d6e7f8091a2b3c4d5e
    branch refs/heads/main

    worktree /Users/dev/Work/multishell-worktrees/feat-tabs
    HEAD 4d90b7e1122334455667788990aabbccddeeff00
    branch refs/heads/feat/tabs

    worktree /Users/dev/Work/multishell-worktrees/spike
    HEAD 1a2e5c9ffeeddccbbaa00998877665544332211
    detached
    locked

    """

  @Test func everyRecordBecomesAWorktree() {
    let worktrees = WorktreeListParser.parse(zeroTerminated(porcelain), projectID: "/repo")
    #expect(worktrees.count == 3)
  }

  @Test func theFirstRecordIsThePrimaryWorktree() {
    let worktrees = WorktreeListParser.parse(zeroTerminated(porcelain), projectID: "/repo")
    #expect(worktrees[0].isPrimary)
    #expect(!worktrees[1].isPrimary)
  }

  @Test func branchRefsAreShortened() {
    let worktrees = WorktreeListParser.parse(zeroTerminated(porcelain), projectID: "/repo")
    #expect(worktrees[0].branch == "main")
    #expect(worktrees[1].branch == "feat/tabs")
  }

  @Test func detachedWorktreesHaveNoBranchAndFallBackToTheShortSHA() {
    let detached = WorktreeListParser.parse(zeroTerminated(porcelain), projectID: "/repo")[2]
    #expect(detached.branch == nil)
    #expect(detached.isDetached)
    #expect(detached.name == "1a2e5c9")
    #expect(detached.isLocked)
  }

  /// The reason for `-z`: with NUL between attributes, a newline in a path
  /// is part of the path rather than the start of another attribute.
  @Test func aNewlineInsideAPathIsPartOfIt() {
    let output = "worktree /Users/dev/my\nrepo\u{0}HEAD 7777777\u{0}branch refs/heads/odd\u{0}"
    let worktrees = WorktreeListParser.parse(output, projectID: "/p")
    #expect(worktrees.map(\.path.path) == ["/Users/dev/my\nrepo"])
    #expect(worktrees[0].branch == "odd")
  }

  @Test func emptyOutputYieldsNothing() {
    #expect(WorktreeListParser.parse("", projectID: "/repo").isEmpty)
  }
}
