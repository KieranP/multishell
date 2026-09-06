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
    let worktrees = WorktreeListParser.parse(porcelain, projectID: "/repo")
    #expect(worktrees.count == 3)
  }

  @Test func theFirstRecordIsThePrimaryWorktree() {
    let worktrees = WorktreeListParser.parse(porcelain, projectID: "/repo")
    #expect(worktrees[0].isPrimary)
    #expect(!worktrees[1].isPrimary)
  }

  @Test func branchRefsAreShortened() {
    let worktrees = WorktreeListParser.parse(porcelain, projectID: "/repo")
    #expect(worktrees[0].branch == "main")
    #expect(worktrees[1].branch == "feat/tabs")
  }

  @Test func detachedWorktreesHaveNoBranchAndFallBackToTheShortSHA() {
    let detached = WorktreeListParser.parse(porcelain, projectID: "/repo")[2]
    #expect(detached.branch == nil)
    #expect(detached.isDetached)
    #expect(detached.name == "1a2e5c9")
    #expect(detached.isLocked)
  }

  @Test func windowsLineEndingsParseIdentically() {
    let crlf = porcelain.replacingOccurrences(of: "\n", with: "\r\n")
    #expect(
      WorktreeListParser.parse(crlf, projectID: "/repo")
        == WorktreeListParser.parse(porcelain, projectID: "/repo"))
  }

  @Test func emptyOutputYieldsNothing() {
    #expect(WorktreeListParser.parse("", projectID: "/repo").isEmpty)
  }
}

@Suite
struct WorktreeListParserEdgeTests {
  @Test func lockedWithAReasonAndPrunableAreStillParsed() {
    let output = """
      worktree /Users/dev/Work/demo
      HEAD 1111111111111111111111111111111111111111
      branch refs/heads/main

      worktree /Users/dev/Work/demo-trees/gone
      HEAD 2222222222222222222222222222222222222222
      branch refs/heads/gone
      prunable gitdir file points to non-existent location

      worktree /Users/dev/Work/demo-trees/busy
      HEAD 3333333333333333333333333333333333333333
      branch refs/heads/busy
      locked reason with spaces
      """
    let worktrees = WorktreeListParser.parse(output, projectID: "/p")
    #expect(worktrees.count == 3)
    #expect(worktrees[1].branch == "gone")
    #expect(!worktrees[1].isLocked)
    #expect(worktrees[2].isLocked)
  }

  @Test func aBareRepositoryIsListedWithNoBranch() {
    let output = """
      worktree /srv/repo.git
      HEAD 4444444444444444444444444444444444444444
      bare

      worktree /srv/checkouts/main
      HEAD 4444444444444444444444444444444444444444
      branch refs/heads/main
      """
    let worktrees = WorktreeListParser.parse(output, projectID: "/p")
    #expect(worktrees[0].isPrimary && worktrees[0].branch == nil)
    #expect(worktrees[0].isBare && !worktrees[0].isDetached)
    #expect(worktrees[0].name == "repo.git")
    #expect(worktrees[1].branch == "main" && !worktrees[1].isBare)
  }

  @Test func pathsWithSpacesSurviveTheKeyValueSplit() {
    let output = """
      worktree /Users/dev/My Projects/demo app
      HEAD 6666666666666666666666666666666666666666
      branch refs/heads/main
      """
    let worktrees = WorktreeListParser.parse(output, projectID: "/p")
    #expect(worktrees.map(\.path.path) == ["/Users/dev/My Projects/demo app"])
    #expect(worktrees[0].branch == "main")
  }

  @Test func anUnbornRepositoryListsItsBranchWithAZeroHead() {
    // What `git worktree list` prints before the first commit.
    let output = """
      worktree /Users/dev/fresh
      HEAD 0000000000000000000000000000000000000000
      branch refs/heads/main
      """
    let worktrees = WorktreeListParser.parse(output, projectID: "/p")
    #expect(worktrees[0].branch == "main")
    #expect(worktrees[0].name == "main")
  }

  @Test func oddOutputNeverCrashesTheParser() {
    let awkward = [
      "worktree", "worktree ", "HEAD", "branch", "\n\n\n", "locked\nworktree /x", "bare",
      "worktree /a\nworktree /b", "\u{1F600}", "worktree /a\nHEAD\nbranch refs/heads/",
    ]
    for output in awkward {
      let worktrees = WorktreeListParser.parse(output, projectID: "/p")
      #expect(worktrees.allSatisfy { !$0.path.path.isEmpty }, "\(output)")
    }
    #expect(
      WorktreeListParser.parse("worktree \n", projectID: "/p").isEmpty,
      "an empty path would resolve to the current directory")
  }

  @Test func missingTrailingBlankLineIsFine() {
    let output = "worktree /a\nHEAD 5555555\nbranch refs/heads/x"
    #expect(WorktreeListParser.parse(output, projectID: "/p").map(\.branch) == ["x"])
  }
}
