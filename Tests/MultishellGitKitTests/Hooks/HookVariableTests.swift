import Testing

@testable import MultishellGitKit

@Suite
struct HookVariableTests {
  @Test func theHookVariablesKeepTheNamesHooksAreWrittenAgainst() {
    #expect(
      HookVariable.allCases.map(\.name) == [
        "MULTISHELL_PROJECT_PATH", "MULTISHELL_PROJECT_NAME", "MULTISHELL_WORKTREE_PATH",
        "MULTISHELL_BRANCH",
      ])
  }
}
