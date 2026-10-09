import Testing

@testable import MultishellCore

@Suite
struct AgentCatalogueCustomCommandTests {
  private var values: [WorktreePlaceholder: String] { WorktreePlaceholder.sampleValues }

  @Test func theCustomLineReadsEachPlaceholderFromTheEnvironmentWhereItsQuoteLeavesIt() {
    let line = AgentCatalogue.customCommandLine(
      #"my-agent --name={{worktree}} "in {{project_path}}" 'at {{worktree_path}}' {{nonsense}}"#,
      values: values)
    #expect(
      line.text
        == #"my-agent --name="$MULTISHELL_WORKTREE_NAME" "in ""$MULTISHELL_PROJECT_PATH""" 'at '"$MULTISHELL_WORKTREE_PATH"'' {{nonsense}}"#
    )
    #expect(
      line.environment == [
        "MULTISHELL_WORKTREE_NAME": "The fix",
        "MULTISHELL_PROJECT_PATH": "/Users/dev/Work/multishell",
        "MULTISHELL_WORKTREE_PATH": "/Users/dev/Work/multishell-worktrees/fix",
      ], "only what the line names")
    #expect(
      AgentCatalogue.customCommandLine(#"my-agent \{{branch}}"#, values: values).text
        == #"my-agent \{{branch}}"#, "an escaped brace is the user's text")
  }

  @Test func theCustomLineReadsTheTaskFromTheEnvironmentAsItDoesAPlaceholder() {
    let line = AgentCatalogue.customCommandLine(
      "my-agent --ask {{task}}", values: values, task: "Fix it\nnow $(touch /tmp/pwned)")

    #expect(line.text == #"my-agent --ask "$MULTISHELL_TASK""#)
    #expect(line.environment == ["MULTISHELL_TASK": "Fix it now $(touch /tmp/pwned)"])
  }
}
