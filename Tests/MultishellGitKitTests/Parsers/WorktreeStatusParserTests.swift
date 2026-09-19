import MultishellCore
import Testing

@testable import MultishellGitKit

@Suite
struct WorktreeStatusParserTests {
  @Test func countsEachKindOfChangeOnce() {
    let output = """
      ## main...origin/main [ahead 2, behind 1]
       M Sources/App.swift
      M  Sources/Model.swift
      MM Sources/Both.swift
      A  New.swift
      ?? scratch.txt
      !! .build/
      UU conflict.swift
      R  old.swift -> new.swift
      """
    let status = WorktreeStatusParser.parse(output)

    #expect(status.changedFiles == 7)
    #expect(status.unstaged == 2)
    #expect(status.staged == 4)
    #expect(status.untracked == 1)
    #expect(status.conflicted == 1)
    #expect(status.ahead == 2)
    #expect(status.behind == 1)
    #expect(status.isDirty)
  }

  @Test func aCleanTreeIsClean() {
    let status = WorktreeStatusParser.parse("## main...origin/main\n")
    #expect(status.isClean)
    #expect(status.summary == "Clean")
  }

  @Test func aheadOnlyIsNotDirtyButNotClean() {
    let status = WorktreeStatusParser.parse("## feat...origin/feat [ahead 3]\n")
    #expect(!status.isDirty)
    #expect(!status.isClean)
    #expect(status.summary == "↑3")
  }

  @Test func branchLinesWithoutUpstreamParse() {
    #expect(WorktreeStatusParser.parse("## HEAD (no branch)\n?? a\n").untracked == 1)
    #expect(WorktreeStatusParser.parse("## No commits yet on main\n").isClean)
  }

  @Test func aDeletedUpstreamIsNotACount() {
    // `[gone]` is what git prints once the remote branch was deleted.
    let status = WorktreeStatusParser.parse("## feat...origin/feat [gone]\n M a.txt\n")
    #expect(status.branch == "feat")
    #expect(status.ahead == 0 && status.behind == 0)
    #expect(status.changedFiles == 1)
  }

  @Test func aDetachedHeadStillCountsChanges() {
    let status = WorktreeStatusParser.parse("## HEAD (no branch)\nA  new.txt\n?? x\n")
    #expect(status.branch == nil)
    #expect(status.staged == 1 && status.untracked == 1 && status.changedFiles == 2)
  }

  @Test func oddLinesNeverCrashTheParser() {
    let awkward = [
      "## ", "##", "#", "M", " ", "", "## [", "## ]", "## a...b [ahead x]", "## a [ahead]",
      "?? 名前.txt", "\u{1F600}\u{1F600} smile", "R  a -> b -> c", "## HEAD (",
    ]
    for line in awkward {
      let status = WorktreeStatusParser.parse(line + "\n")
      #expect(status.ahead >= 0 && status.behind >= 0, "\(line)")
    }
    let all = WorktreeStatusParser.parse(awkward.joined(separator: "\n"))
    #expect(all.changedFiles >= 0)
  }

  @Test func theBranchNameIsExtractedFromEveryHeaderShape() {
    #expect(WorktreeStatusParser.parse("## main...origin/main [ahead 2]\n").branch == "main")
    #expect(WorktreeStatusParser.parse("## feat/tabs\n").branch == "feat/tabs")
    #expect(WorktreeStatusParser.parse("## HEAD (no branch)\n").branch == nil)
    #expect(WorktreeStatusParser.parse("## No commits yet on trunk\n").branch == "trunk")
  }

  /// What a clone of an empty repository reports: git writes the upstream at
  /// clone time, so the unborn branch has one before the first commit.
  @Test func anUnbornBranchWithAnUpstreamIsNamedWithoutIt() {
    #expect(
      WorktreeStatusParser.parse("## No commits yet on main...origin/main [gone]\n").branch
        == "main")
    #expect(
      WorktreeStatusParser.parse("## Initial commit on main...origin/main\n").branch == "main")
  }
}
