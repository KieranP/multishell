import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

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
    #expect(AgentLaunch.command(customLine: "  ", shell: zsh, exec: "exec /bin/zsh -l") == nil)
    #expect(
      AgentLaunch.command(customLine: " aider --model x \n", shell: zsh, exec: "exec /bin/zsh -l")?
        .last == "aider --model x; exec /bin/zsh -l")
  }

  /// A dropped file is named to the agent the way its prompt reads one;
  /// the catalogue says so only where that is known.
  @Test func theCatalogueSaysWhichAgentsReadFileMentions() {
    #expect(AgentCatalogue.agent("claude")?.fileMentionPrefix == "@")
    #expect(AgentCatalogue.agent("aider")?.fileMentionPrefix == nil)
  }

  @Test func resumeUsesTheCatalogueOrGivesUp() {
    let claude = AgentCatalogue.agent("claude")!
    #expect(AgentLaunch.arguments(for: claude, resume: false) == ["claude"])
    #expect(AgentLaunch.arguments(for: claude, resume: true) == ["claude", "--continue"])
    let gemini = AgentCatalogue.agent("gemini")!
    #expect(AgentLaunch.arguments(for: gemini, resume: true) == ["gemini", "--resume", "latest"])
    let aider = AgentCatalogue.agent("aider")!
    #expect(AgentLaunch.arguments(for: aider, resume: true) == nil, "no resume flag: plain shell")
  }
}
