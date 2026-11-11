import Foundation
import Testing

@testable import MultishellCore

@Suite
struct AgentFlagsTests {
  private let project = WorktreePlaceholder.sampleProject
  private var values: [WorktreePlaceholder: String] { WorktreePlaceholder.sampleValues }

  @Test func aFlagLineBecomesArgumentsWithItsPlaceholdersFilledIn() {
    #expect(
      AgentFlags.arguments("--name={{branch}} --model opus", values: values)
        == ["--name=kieran/fix", "--model", "opus"]
    )
    #expect(AgentFlags.arguments("   ", values: values) == [], "blank passes nothing")
  }

  /// The value is one argument however it is spelled, which is the reason
  /// the line is split here rather than handed to the shell as text.
  @Test func aValueWithASpaceStaysOneArgument() {
    #expect(AgentFlags.arguments("--name={{worktree}}", values: values) == ["--name=The fix"])
    #expect(
      AgentFlags.arguments("--prompt 'be brief' --cwd {{worktree_path}}", values: values)
        == ["--prompt", "be brief", "--cwd", "/Users/dev/Work/multishell-worktrees/fix"]
    )
  }

  @Test func anUnknownPlaceholderIsLeftAsTyped() {
    #expect(AgentFlags.arguments("--name={{nonsense}}", values: values) == ["--name={{nonsense}}"])
  }

  /// Substituted text is text. A branch named after a placeholder was being
  /// scanned again by the placeholders that come after it in the list.
  @Test func aValueHoldingAPlaceholderIsNotExpandedAgain() {
    let odd = Worktree(
      path: URL(fileURLWithPath: "/Users/dev/Work/multishell-worktrees/odd"),
      projectID: project.id,
      head: "abc1234",
      branch: "feat/{{project}}",
    )
    let values = WorktreePlaceholder.values(
      project: project,
      worktree: odd,
      worktreeName: "{{project_path}}",
      port: nil,
    )

    #expect(
      AgentFlags.arguments("--name={{branch}}", values: values) == ["--name=feat/{{project}}"]
    )
    #expect(AgentFlags.arguments("--w={{worktree}}", values: values) == ["--w={{project_path}}"])
    #expect(
      AgentCatalogue.customCommandLine(
        "run --name={{branch}}",
        values: values,
        forShellNamed: "zsh",
      ).environment
        == ["MULTISHELL_BRANCH": "feat/{{project}}"]
    )
  }

  /// A branch name is whatever anyone pushed, and both paths hand it to a shell.
  /// TabCommandTests runs the flag path through real shells.
  @Test func aBranchNameCannotRunACommandOnEitherPath() {
    for hostile in ["$(touch /tmp/pwned)", "`touch /tmp/pwned`", "a;touch /tmp/pwned"] {
      let values = WorktreePlaceholder.sampleValues(branch: hostile)

      let flags = AgentFlags.arguments("--name={{branch}}", values: values)
      #expect(flags == ["--name=\(hostile)"], "one argument, expanded but not run")

      let custom = AgentCatalogue.customCommandLine(
        "my-agent --name={{branch}}",
        values: values,
        forShellNamed: "zsh",
      )
      #expect(custom.text == "my-agent --name=\"$MULTISHELL_BRANCH\"", "read, never written in")
      #expect(custom.environment == ["MULTISHELL_BRANCH": hostile])
    }
  }

  @Test func aWorktreeWithoutAPortBlockLeavesThePortTokenAsTyped() {
    let values = WorktreePlaceholder.values(
      project: project,
      worktree: Worktree(path: URL(fileURLWithPath: "/w"), projectID: project.id, head: "a"),
      worktreeName: "w",
      port: nil,
    )

    #expect(AgentFlags.arguments("--port={{port}}", values: values) == ["--port={{port}}"])
  }
}
