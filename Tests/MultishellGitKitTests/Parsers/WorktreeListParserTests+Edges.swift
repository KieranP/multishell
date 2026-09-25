import Foundation
import MultishellCore
import Testing

@testable import MultishellGitKit

extension WorktreeListParserTests {
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
    let worktrees = WorktreeListParser.parse(zeroTerminated(output), projectID: "/p")
    #expect(worktrees.count == 3)
    #expect(worktrees[1].branch == "gone")
    #expect(!worktrees[1].isLocked)
    #expect(worktrees[2].isLocked)
  }

  @Test func aWorktreeGitIsStillMakingIsMarkedAsSo() {
    let output = """
      worktree /w/demo
      HEAD 1111111111111111111111111111111111111111
      branch refs/heads/main

      worktree /w/making
      HEAD 2222222222222222222222222222222222222222
      branch refs/heads/making
      locked initializing

      worktree /w/pinned
      HEAD 3333333333333333333333333333333333333333
      branch refs/heads/pinned
      locked initializing the drive
      """
    let worktrees = WorktreeListParser.parse(zeroTerminated(output), projectID: "/p")
    #expect(worktrees.map(\.isInitializing) == [false, true, false])
    #expect(worktrees[1].isLocked)
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
    let worktrees = WorktreeListParser.parse(zeroTerminated(output), projectID: "/p")
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
    let worktrees = WorktreeListParser.parse(zeroTerminated(output), projectID: "/p")
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
    let worktrees = WorktreeListParser.parse(zeroTerminated(output), projectID: "/p")
    #expect(worktrees[0].branch == "main")
    #expect(worktrees[0].name == "main")
  }

  @Test func oddOutputNeverCrashesTheParser() {
    let awkward = [
      "worktree", "worktree ", "HEAD", "branch", "\n\n\n", "locked\nworktree /x", "bare",
      "worktree /a\nworktree /b", "\u{1F600}", "worktree /a\nHEAD\nbranch refs/heads/",
    ]
    for output in awkward {
      let worktrees = WorktreeListParser.parse(zeroTerminated(output), projectID: "/p")
      #expect(worktrees.allSatisfy { !$0.path.path.isEmpty }, "\(output)")
    }
    #expect(
      WorktreeListParser.parse(zeroTerminated("worktree \n"), projectID: "/p").isEmpty,
      "an empty path would resolve to the current directory")
  }

  @Test func missingTrailingBlankLineIsFine() {
    let output = "worktree /a\nHEAD 5555555\nbranch refs/heads/x"
    #expect(
      WorktreeListParser.parse(zeroTerminated(output), projectID: "/p").map(\.branch) == ["x"])
  }
}
