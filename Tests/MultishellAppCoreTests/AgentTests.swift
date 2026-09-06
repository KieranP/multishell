import Foundation
import MultishellCore
import MultishellProcess
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

  @Test func resumeUsesTheCatalogueOrGivesUp() {
    let claude = AgentCatalogue.agent("claude")!
    #expect(AgentLaunch.arguments(for: claude, resume: false) == ["claude"])
    #expect(AgentLaunch.arguments(for: claude, resume: true) == ["claude", "--continue"])
    let gemini = AgentCatalogue.agent("gemini")!
    #expect(AgentLaunch.arguments(for: gemini, resume: true) == nil, "no resume flag: plain shell")
  }
}

@Suite
struct AgentDetectionTests {
  @Test func agentsAreFoundOnTheGivenPathOnly() throws {
    let bin = try fakeBin(["claude", "aider"])
    defer { try? FileManager.default.removeItem(at: bin) }

    let detection = AgentDetection(path: "/usr/bin:\(bin.path)")
    #expect(Set(detection.found.keys) == ["claude", "aider"])
    #expect(detection.isClaudeCodeInstalled)
    #expect(detection.found["claude"]?.path == bin.appendingPathComponent("claude").path)
    #expect(!AgentDetection(path: "/usr/bin").isClaudeCodeInstalled)
  }

  @Test func theDropdownListsInstalledAgentsTheStaleChoiceAndCustom() throws {
    let bin = try fakeBin(["codex"])
    defer { try? FileManager.default.removeItem(at: bin) }
    let detection = AgentDetection(path: bin.path)

    let plain = detection.options(selected: nil).map(\.id)
    #expect(plain == ["none", "codex", "custom"])

    let stale = detection.options(selected: "claude")
    #expect(stale.map(\.id) == ["none", "claude", "codex", "custom"], "catalogue order")
    #expect(stale[1].label == "Claude Code (not installed)")
    #expect(!stale[1].isInstalled)

    let unknown = detection.options(selected: "future-agent")
    #expect(unknown.map(\.id).contains("future-agent"), "a newer build's id still shows")
    #expect(detection.isInstalled("custom"))
    #expect(!detection.isInstalled("claude"))
  }
}
