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

  @Test func theBranchNameIsExtractedFromEveryHeaderShape() {
    #expect(WorktreeStatusParser.parse("## main...origin/main [ahead 2]\n").branch == "main")
    #expect(WorktreeStatusParser.parse("## feat/tabs\n").branch == "feat/tabs")
    #expect(WorktreeStatusParser.parse("## HEAD (no branch)\n").branch == nil)
    #expect(WorktreeStatusParser.parse("## No commits yet on trunk\n").branch == "trunk")
  }
}
