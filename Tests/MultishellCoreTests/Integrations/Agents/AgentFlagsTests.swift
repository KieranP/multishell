import Foundation
import Testing

@testable import MultishellCore

@Suite
struct AgentFlagsTests {
  private let project = Project(path: URL(fileURLWithPath: "/Users/dev/Work/multishell"))
  private var worktree: Worktree {
    Worktree(
      path: URL(fileURLWithPath: "/Users/dev/Work/multishell-worktrees/fix"),
      projectID: project.id, head: "abc1234", branch: "kieran/fix")
  }
  private var values: [AgentPlaceholder: String] {
    AgentPlaceholder.values(project: project, worktree: worktree, name: "The fix")
  }

  @Test func aFlagLineBecomesArgumentsWithItsPlaceholdersFilledIn() {
    #expect(
      AgentFlags.arguments("--name={{branch}} --model opus", values: values)
        == ["--name=kieran/fix", "--model", "opus"])
    #expect(AgentFlags.arguments("   ", values: values) == [], "blank passes nothing")
  }

  /// The value is one argument however it is spelled, which is the reason
  /// the line is split here rather than handed to the shell as text.
  @Test func aValueWithASpaceStaysOneArgument() {
    #expect(AgentFlags.arguments("--name={{worktree}}", values: values) == ["--name=The fix"])
    #expect(
      AgentFlags.arguments("--prompt 'be brief' --cwd {{worktree_path}}", values: values)
        == ["--prompt", "be brief", "--cwd", "/Users/dev/Work/multishell-worktrees/fix"])
    #expect(AgentFlags.split(#"--a "b c" d\ e"#) == ["--a", "b c", "d e"])
    #expect(AgentFlags.split("--a ''") == ["--a", ""], "an empty quoted word is an argument")
    #expect(AgentFlags.split("--a 'b c") == ["--a", "b c"], "a quote left open takes the rest")
  }

  /// Checked case by case against zsh, and the whole rule against it by
  /// random lines over letters, spaces and the three quoting characters.
  @Test func aBackslashInsideDoubleQuotesGuardsOnlyTheFourTheShellGuards() {
    #expect(AgentFlags.split(#""\d+""#) == [#"\d+"#], "a regex keeps its backslashes")
    #expect(AgentFlags.split(##""\\""##) == [#"\"#], "two guard one")
    #expect(AgentFlags.split(##""\"""##) == [#"""#], "and one guards the quote that would end it")
    #expect(AgentFlags.split(##""\$""##) == ["$"])
    #expect(AgentFlags.split(##""\`""##) == ["`"])
    #expect(AgentFlags.split(#"\d"#) == ["d"], "outside quotes it guards everything")
    #expect(AgentFlags.split(#"'\d'"#) == [#"\d"#], "inside single quotes it guards nothing")
  }

  @Test func anUnterminatedQuoteWithNothingInItPassesNothing() {
    #expect(AgentFlags.split("--prompt \"") == ["--prompt"])
    #expect(AgentFlags.split("--prompt '") == ["--prompt"])
    #expect(AgentFlags.split("--prompt ''") == ["--prompt", ""], "closed, so it is an argument")
    #expect(AgentFlags.split("--prompt 'b") == ["--prompt", "b"], "it did carry something")
  }

  /// An escape nothing completed used to end the line with an empty word,
  /// which reached the agent as an argument of its own.
  @Test func aTrailingBackslashPassesNothingRatherThanAnEmptyArgument() {
    #expect(AgentFlags.split("--model opus \\") == ["--model", "opus"])
    #expect(AgentFlags.split("\\") == [])
    #expect(AgentFlags.split("\\a") == ["a"], "the word still starts on the escaped character")
  }

  @Test func anUnknownPlaceholderIsLeftAsTyped() {
    #expect(AgentFlags.arguments("--name={{nonsense}}", values: values) == ["--name={{nonsense}}"])
  }

  /// Substituted text is text. A branch named after a placeholder was being
  /// scanned again by the placeholders that come after it in the list.
  @Test func aValueHoldingAPlaceholderIsNotExpandedAgain() {
    let odd = Worktree(
      path: URL(fileURLWithPath: "/Users/dev/Work/multishell-worktrees/odd"),
      projectID: project.id, head: "abc1234", branch: "feat/{{project}}")
    let values = AgentPlaceholder.values(project: project, worktree: odd, name: "{{project_path}}")

    #expect(
      AgentFlags.arguments("--name={{branch}}", values: values) == ["--name=feat/{{project}}"])
    #expect(AgentFlags.arguments("--w={{worktree}}", values: values) == ["--w={{project_path}}"])
    #expect(
      AgentFlags.expand("run --name={{branch}}", values: values)
        == "run --name='feat/{{project}}'")
  }

  @Test func everyPlaceholderHasAValue() {
    let values = self.values
    #expect(values[.branch] == "kieran/fix")
    #expect(values[.worktree] == "The fix")
    #expect(values[.worktreePath] == "/Users/dev/Work/multishell-worktrees/fix")
    #expect(values[.project] == "multishell")
    #expect(values[.projectPath] == "/Users/dev/Work/multishell")
    #expect(
      values.count == AgentPlaceholder.allCases.count, "a case with no value expands to nothing")
  }

  @Test func aDetachedWorktreeFallsBackToItsShortSHA() {
    let detached = Worktree(
      path: URL(fileURLWithPath: "/w"), projectID: project.id, head: "abc1234def")
    let values = AgentPlaceholder.values(project: project, worktree: detached, name: "abc1234")
    #expect(values[.branch] == "abc1234", "never the empty string: `--name=` is worse")
  }

  /// A branch name is whatever anyone pushed, and both paths hand it to a
  /// shell. Checked against a real zsh when this was written: every one of
  /// these reaches the agent as one literal argument, and none of them runs
  /// anything.
  @Test func aBranchNameCannotRunACommandOnEitherPath() {
    for hostile in ["$(touch /tmp/pwned)", "`touch /tmp/pwned`", "a;touch /tmp/pwned"] {
      let worktree = Worktree(
        path: URL(fileURLWithPath: "/repos/demo-worktrees/w"), projectID: project.id, head: "a",
        branch: hostile)
      let values = AgentPlaceholder.values(project: project, worktree: worktree, name: hostile)

      let flags = AgentFlags.arguments("--name={{branch}}", values: values)
      #expect(flags == ["--name=\(hostile)"], "one argument, expanded but not run")
      #expect(
        ShellQuoting.commandLine(flags) == "'--name=\(hostile)'",
        "single-quoted on the way to the command line, so the shell reads it as text")

      let custom = AgentFlags.expand("my-agent --name={{branch}}", values: values)
      #expect(custom == "my-agent --name='\(hostile)'", "quoted where it lands")
    }
  }

  /// The custom command runs as text, so a value lands in it quoted.
  @Test func theCustomLineTakesPlaceholdersQuoted() {
    #expect(
      AgentFlags.expand("my-agent --name={{worktree}}", values: values)
        == "my-agent --name='The fix'")
    #expect(
      AgentFlags.expand("my-agent --branch {{branch}}", values: values)
        == "my-agent --branch kieran/fix", "nothing to quote")
  }
}

@Suite
struct AgentFlagResolutionTests {
  private let project = Project(path: URL(fileURLWithPath: "/repos/a"))

  @Test func aProjectsFlagsOverrideTheGlobalOnesForItsAgent() {
    var workspace = Workspace()
    workspace.preferredAgentID = AgentCatalogue.claudeID
    workspace.agentFlags = ["claude": "--model opus", "codex": "--full-auto"]

    #expect(workspace.agentFlags(for: project, agent: "claude") == "--model opus")
    #expect(workspace.agentFlags(for: project, agent: "codex") == "--full-auto")
    #expect(workspace.agentFlags(for: project, agent: "aider") == "", "nothing stored")

    let quiet = Project(path: project.path, settings: ProjectSettings(agentFlags: ""))
    #expect(quiet.settings.agentFlags != nil, "blank is an override, not an absent key")
    #expect(
      workspace.agentFlags(for: quiet, agent: "claude") == "",
      "a project can run the agent bare under a global that passes flags")

    let own = Project(path: project.path, settings: ProjectSettings(agentFlags: "--model haiku"))
    #expect(workspace.agentFlags(for: own, agent: "claude") == "--model haiku")
  }

  /// The settings field writes on every keystroke, so the space between two
  /// flags has to survive being typed; only an empty line drops the entry.
  @Test @MainActor func storingFlagsKeepsWhatWasTypedAndClearingRemovesTheEntry() {
    let store = WorkspaceStore()
    store.setAgentFlags("--model opus ", for: "claude")
    #expect(store.workspace.agentFlags["claude"] == "--model opus ")
    store.setAgentFlags(" ", for: "claude")
    #expect(store.workspace.agentFlags["claude"] == " ", "a space is a flag half typed")
    store.setAgentFlags("", for: "claude")
    #expect(store.workspace.agentFlags["claude"] == nil, "cleared, so nothing is left behind")
  }
}
