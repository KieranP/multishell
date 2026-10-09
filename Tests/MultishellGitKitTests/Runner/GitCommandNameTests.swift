import Testing

@testable import MultishellGitKit

@Suite
struct GitCommandNameTests {
  @Test func aRunIsNamedBySubcommandAndFlagsWithoutValuesOrOperands() {
    #expect(
      GitCommandName.of(["rev-list", "--left-right", "--count", "main...feature"])
        == "rev-list --left-right --count"
    )
    #expect(
      GitCommandName.of(["for-each-ref", "--format=%(refname)", "refs/heads"])
        == "for-each-ref --format"
    )
  }

  @Test func flagsAfterTheSeparatorAndRepeatsAreNotNamedAgain() {
    #expect(
      GitCommandName.of(["log", "-z", "--format=%H", "--format=%s", "--", "-file"])
        == "log -z --format"
    )
    #expect(GitCommandName.of([]) == "")
  }

  @Test func globalOptionsBeforeTheSubcommandAreLeftOutOfTheName() {
    #expect(
      GitCommandName.of(["--no-optional-locks", "status", "--porcelain=v1", "--branch"])
        == "status --porcelain --branch"
    )
    #expect(
      GitCommandName.of(["-C", "/repo", "-c", "core.quotePath=false", "diff", "--numstat"])
        == "diff --numstat"
    )
  }

  @Test func aSubcommandWithActionsIsNamedWithItsAction() {
    #expect(
      GitCommandName.of(["worktree", "remove", "--force", "--force", "/repo/feature"])
        == "worktree remove --force"
    )
    #expect(GitCommandName.of(["worktree", "prune"]) == "worktree prune")
    #expect(
      GitCommandName.of(["worktree", "list", "--porcelain", "-z"])
        == "worktree list --porcelain -z"
    )
  }
}
