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

@Suite
struct AgentDetectionTests {
  @Test func agentsAreFoundOnTheGivenPathOnly() throws {
    let bin = try fakeBin(["claude", "aider"])
    defer { try? FileManager.default.removeItem(at: bin) }

    let detection = AgentDetection(path: "/usr/bin:\(bin.path)")
    #expect(Set(detection.found.keys) == ["claude", "aider"])
    #expect(detection.found["claude"]?.path == bin.appendingPathComponent("claude").path)
    #expect(detection.isInstalled("claude"))
    #expect(!detection.isInstalled("codex"))
    #expect(AgentDetection(path: "/usr/bin").found.isEmpty, "nothing on a path with no agents")
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

@Suite
struct AgentHooksRowTests {
  private func detection(_ ids: [String]) -> AgentDetection {
    AgentDetection(
      found: Dictionary(uniqueKeysWithValues: ids.map { ($0, URL(fileURLWithPath: "/bin/\($0)")) }))
  }

  /// An agent this machine has gets a row, and so does one whose hooks are
  /// still installed after it has gone: those have to be removable.
  @Test func rowsAreForTheAgentsHereAndTheHooksLeftBehind() {
    let rows = AgentHooksRow.rows(
      detection: detection(["claude", "gemini", "aider"]), installed: ["codex"])

    #expect(rows.map(\.id) == ["claude", "codex", "gemini"], "catalogue order")
    #expect(rows.first { $0.id == "codex" }?.isInstalled == true)
    #expect(rows.first { $0.id == "claude" }?.isInstalled == false)
    #expect(!rows.contains { $0.id == "aider" }, "no hooks to offer")
    #expect(!rows.contains { $0.id == "copilot" }, "not on this machine")
  }

  @Test func eachRowNamesItsFileAndWhatWritingItDoes() throws {
    let rows = AgentHooksRow.rows(
      detection: detection(["claude", "codex", "copilot", "opencode"]), installed: [])
    let claude = try #require(rows.first { $0.id == "claude" })
    let codex = try #require(rows.first { $0.id == "codex" })
    let copilot = try #require(rows.first { $0.id == "copilot" })
    let openCode = try #require(rows.first { $0.id == "opencode" })

    #expect(claude.path == "~/.claude/settings.json")
    #expect(claude.info.contains("Other hooks in ~/.claude/settings.json are left as they are"))
    #expect(claude.contentsName == "JSON")
    #expect(copilot.info.contains("Multishell's own file"), "nothing of the user's to keep")
    #expect(codex.info.contains("/hooks in Codex"), "it runs no hook it has not been told to trust")
    #expect(!claude.info.contains("/hooks in Codex"))
    #expect(openCode.contentsName == "Plugin")
    for row in rows { #expect(row.info.contains(row.name)) }
  }
}
