import Foundation
import Testing

@testable import MultishellCore

@Suite
struct WorktreePlaceholderTests {
  private let project = WorktreePlaceholder.sampleProject
  private var values: [WorktreePlaceholder: String] { WorktreePlaceholder.sampleValues }

  @Test func everyPlaceholderHasAValue() {
    let values = self.values
    #expect(values[.branch] == "kieran/fix")
    #expect(values[.worktree] == "The fix")
    #expect(values[.worktreePath] == "/Users/dev/Work/multishell-worktrees/fix")
    #expect(values[.project] == "multishell")
    #expect(values[.projectPath] == "/Users/dev/Work/multishell")
    #expect(
      values.count == WorktreePlaceholder.allCases.count, "a case with no value expands to nothing")
  }

  @Test func aDetachedWorktreeFallsBackToItsShortSHA() {
    let detached = Worktree(
      path: URL(fileURLWithPath: "/w"), projectID: project.id, head: "abc1234def")
    let values = WorktreePlaceholder.values(
      project: project, worktree: detached, worktreeName: "abc1234")
    #expect(values[.branch] == "abc1234", "never the empty string: `--name=` is worse")
  }
}
