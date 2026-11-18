import Testing

@testable import MultishellGitKit

@Suite
struct GitCommandNameTests {
  @Test func aRunIsNamedByGitItsSubcommandAndFlagsWithoutValuesOrOperands() {
    #expect(
      GitCommandName.of(["rev-list", "--left-right", "--count", "main...feature"])
        == "git rev-list --left-right --count"
    )
    #expect(
      GitCommandName.of(["for-each-ref", "--format=%(refname)", "refs/heads"])
        == "git for-each-ref --format"
    )
  }

  @Test func flagsAfterTheSeparatorAndRepeatsAreNotNamedAgain() {
    #expect(
      GitCommandName.of(["log", "-z", "--format=%H", "--format=%s", "--", "-file"])
        == "git log -z --format"
    )
    #expect(GitCommandName.of([]) == "git")
  }

  @Test func globalOptionsBeforeTheSubcommandAreLeftOutOfTheName() {
    #expect(
      GitCommandName.of(["--no-optional-locks", "status", "--porcelain=v1", "--branch"])
        == "git status --porcelain --branch"
    )
    #expect(
      GitCommandName.of(["-C", "/repo", "-c", "core.quotePath=false", "diff", "--numstat"])
        == "git diff --numstat"
    )
  }

  @Test func aSubcommandWithActionsIsNamedWithItsAction() {
    #expect(
      GitCommandName.of(["worktree", "remove", "--force", "--force", "/repo/feature"])
        == "git worktree remove --force"
    )
    #expect(GitCommandName.of(["worktree", "prune"]) == "git worktree prune")
    #expect(
      GitCommandName.of(["worktree", "list", "--porcelain", "-z"])
        == "git worktree list --porcelain -z"
    )
  }
}
