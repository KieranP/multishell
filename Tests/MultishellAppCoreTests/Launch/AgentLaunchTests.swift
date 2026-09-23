import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite
struct AgentLaunchTests {
  private let zsh = (executable: URL(fileURLWithPath: "/bin/zsh"), arguments: ["-l", "-i", "-c"])

  @Test func theAgentRunsInTheLoginShellAndAShellTakesOverAfterIt() {
    let command = AgentLaunch.command(
      agent: ["claude", "--continue"], shell: zsh, exec: "exec /bin/zsh -l")
    #expect(command == ["/bin/zsh", "-l", "-i", "-c", "claude --continue; exec /bin/zsh -l"])
  }

  @Test func argumentsWithSpacesAreQuotedAndTheUsersShellIsExecd() {
    let command = AgentLaunch.command(
      agent: ["my agent", "--name", "it's"], shell: zsh, exec: "exec /opt/homebrew/bin/nu -l")
    #expect(command.last == "'my agent' --name 'it'\\''s'; exec /opt/homebrew/bin/nu -l")
  }

  @Test func aCustomLineIsUsedAsTypedAndBlankMeansNothing() {
    #expect(
      AgentLaunch.command(customLine: ShellLine(text: "  "), shell: zsh, exec: "exec /bin/zsh -l")
        == nil)
    #expect(
      AgentLaunch.command(
        customLine: ShellLine(text: " my-agent --model x \n"), shell: zsh,
        exec: "exec /bin/zsh -l")
        == ["/bin/zsh", "-l", "-i", "-c", "my-agent --model x; exec /bin/zsh -l"])
  }

  @Test func theValuesACustomLineReadsAreSetAroundTheShellByEnv() {
    let line = ShellLine(
      text: #"my-agent --name "$MULTISHELL_BRANCH""#,
      environment: ["MULTISHELL_BRANCH": "feat$(x)", "MULTISHELL_PROJECT_NAME": "demo"])
    #expect(
      AgentLaunch.command(customLine: line, shell: zsh, exec: "exec /bin/zsh -l") == [
        "/usr/bin/env", "MULTISHELL_BRANCH=feat$(x)", "MULTISHELL_PROJECT_NAME=demo",
        "/bin/zsh", "-l", "-i", "-c", #"my-agent --name "$MULTISHELL_BRANCH"; exec /bin/zsh -l"#,
      ])
  }

  /// A dropped file is named to the agent the way its prompt reads one;
  /// the catalogue says so only where that is known.
  @Test func theCatalogueSaysWhichAgentsReadFileMentions() {
    #expect(AgentCatalogue.agent("claude")?.fileMentionPrefix == "@")
    #expect(AgentCatalogue.agent("codex")?.fileMentionPrefix == nil)
  }

  @Test func resumeUsesTheCatalogueOrGivesUp() {
    let claude = AgentCatalogue.agent("claude")!
    #expect(AgentLaunch.arguments(for: claude, resume: false) == ["claude"])
    #expect(AgentLaunch.arguments(for: claude, resume: true) == ["claude", "--continue"])
    let gemini = AgentCatalogue.agent("gemini")!
    #expect(AgentLaunch.arguments(for: gemini, resume: true) == ["gemini", "--resume", "latest"])
    // Every agent in the catalogue resumes today, so the no-flag arm is
    // shown against a descriptor rather than left uncovered.
    let flagless = AgentDescriptor(
      id: "flagless", name: "Flagless", executable: "flagless", mark: .monogram("Fl"))
    #expect(
      AgentLaunch.arguments(for: flagless, resume: true) == nil, "no resume flag: plain shell")
  }
}
