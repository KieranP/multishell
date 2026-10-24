import MultishellCore
import Testing

@testable import MultishellGitKit

@Suite
struct WorktreeStatusParserTests {
  @Test func eachKindOfChangeIsCountedOnce() {
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
    let status = WorktreeStatusParser.parse(zeroTerminated(output)).status

    #expect(status.changedFiles == 7)
    #expect(status.unstaged == 2)
    #expect(status.staged == 4)
    #expect(status.untracked == 1)
    #expect(status.conflicted == 1)
    #expect(status.ahead == 2)
    #expect(status.behind == 1)
    #expect(status.isDirty)
  }

  @Test func aCleanTreeOnItsUpstreamIsCleanAndInSync() {
    let status = WorktreeStatusParser.parse(zeroTerminated("## main...origin/main\n")).status
    #expect(status.isCleanAndInSync)
    #expect(status.summary == "Clean")
  }

  @Test func aheadOnlyIsNotDirtyButNotInSync() {
    let status = WorktreeStatusParser.parse(zeroTerminated("## feat...origin/feat [ahead 3]\n"))
      .status
    #expect(!status.isDirty)
    #expect(!status.isCleanAndInSync)
    #expect(status.summary == "↑3")
  }

  @Test func aHeaderWithNoUpstreamStillReadsTheChangesUnderIt() {
    #expect(
      WorktreeStatusParser.parse(zeroTerminated("## HEAD (no branch)\n?? a\n")).status.untracked
        == 1
    )
    #expect(
      WorktreeStatusParser.parse(zeroTerminated("## No commits yet on main\n")).status
        .isCleanAndInSync
    )
  }

  @Test func aDeletedUpstreamIsNotACount() {
    // `[gone]` is what git prints once the remote branch was deleted.
    let status = WorktreeStatusParser.parse(
      zeroTerminated("## feat...origin/feat [gone]\n M a.txt\n")
    ).status
    #expect(status.branch == "feat")
    #expect(status.ahead == 0 && status.behind == 0)
    #expect(status.changedFiles == 1)
  }

  @Test func aDetachedHeadStillCountsChanges() {
    let status = WorktreeStatusParser.parse(
      zeroTerminated("## HEAD (no branch)\nA  new.txt\n?? x\n")
    ).status
    #expect(status.branch == nil)
    #expect(status.staged == 1 && status.untracked == 1 && status.changedFiles == 2)
  }

  @Test func oddLinesNeverCrashTheParser() {
    let awkward = [
      "## ", "##", "#", "M", " ", "", "## [", "## ]", "## a...b [ahead x]", "## a [ahead]",
      "?? 名前.txt", "\u{1F600}\u{1F600} smile", "R  a -> b -> c", "## HEAD (",
    ]
    for line in awkward {
      let status = WorktreeStatusParser.parse(line + "\0").status
      #expect(status.ahead >= 0 && status.behind >= 0, "\(line)")
    }
    let all = WorktreeStatusParser.parse(awkward.joined(separator: "\0")).status
    #expect(all.changedFiles >= 0)
  }

  @Test func theBranchNameIsExtractedFromEveryHeaderShape() {
    #expect(
      WorktreeStatusParser.parse(zeroTerminated("## main...origin/main [ahead 2]\n")).status.branch
        == "main"
    )
    #expect(
      WorktreeStatusParser.parse(zeroTerminated("## feat/tabs\n")).status.branch == "feat/tabs"
    )
    #expect(
      WorktreeStatusParser.parse(zeroTerminated("## HEAD (no branch)\n")).status.branch == nil
    )
    #expect(
      WorktreeStatusParser.parse(zeroTerminated("## No commits yet on trunk\n")).status.branch
        == "trunk"
    )
  }

  /// What a clone of an empty repository reports: git writes the upstream at
  /// clone time, so the unborn branch has one before the first commit.
  @Test func anUnbornBranchWithAnUpstreamIsNamedWithoutIt() {
    #expect(
      WorktreeStatusParser.parse(zeroTerminated("## No commits yet on main...origin/main [gone]\n"))
        .status.branch
        == "main"
    )
    #expect(
      WorktreeStatusParser.parse(zeroTerminated("## Initial commit on main...origin/main\n")).status
        .branch == "main"
    )
  }

  @Test func aPathKeepsItsNewlineAndALeadingCombiningMark() {
    let output = "## main\0 M odd\nname.txt\0?? \u{301}accent.txt\0"

    let entries = WorktreeStatusParser.parse(output).entries

    #expect(entries.map(\.path) == ["odd\nname.txt", "\u{301}accent.txt"])
    #expect(entries.map(\.isUntracked) == [false, true])
  }

  @Test func theBranchLineNamesItsUpstreamOrNone() {
    let tracked = WorktreeStatusParser.parse(zeroTerminated("## main...origin/main [behind 1]\n"))
    #expect(tracked.status.upstream == "origin/main")
    #expect(WorktreeStatusParser.parse(zeroTerminated("## main\n")).status.upstream == nil)
    let unborn = WorktreeStatusParser.parse(
      zeroTerminated("## No commits yet on main...origin/main\n")
    )
    #expect(unborn.status.upstream == "origin/main")
  }
}
