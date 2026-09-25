import Foundation
import Testing

@testable import MultishellCore

/// A file an older build wrote, told apart from what this build writes.
@Suite
struct AgentHookIntegrationStatusTests: AgentHookFixtures {
  @Test func oneReadAnswersInstalledAndCurrentAsTheTwoReadsDo() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let ours = directory.appendingPathComponent("hooks/multishell.json")
    let shared = directory.appendingPathComponent(".codex/hooks.json")
    try FileManager.default.createDirectory(
      at: shared.deletingLastPathComponent(), withIntermediateDirectories: true)
    let copilot = AgentHookCatalogue.copilot
    let codex = AgentHookCatalogue.codex

    #expect(copilot.installation(in: ours, helper: helper) == .absent)
    try copilot.install(into: ours, helper: helper)
    #expect(copilot.installation(in: ours, helper: helper) == .current)
    try #"{"version":1,"hooks":{"SubagentStart":[{"command":"multishell agent-hook"}]}}"#
      .write(to: ours, atomically: true, encoding: .utf8)
    #expect(copilot.installation(in: ours, helper: helper) == .stale)

    #expect(codex.installation(in: shared, helper: helper) == .absent)
    try JSONSerialization.data(withJSONObject: try staleCodexSettings()).write(to: shared)
    #expect(codex.installation(in: shared, helper: helper) == .stale)
    try codex.install(into: shared, helper: helper)
    #expect(codex.installation(in: shared, helper: helper) == .current)
  }

  @Test func aFileOfOursAnOlderBuildWroteOrTheUserEditedIsStaleUntilUpdate() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("hooks/multishell.json")
    let copilot = AgentHookCatalogue.copilot
    try FileManager.default.createDirectory(
      at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    try #"{"version":1,"hooks":{"Stop":[{"command":"multishell agent-hook","timeoutSec":9}]}}"#
      .write(to: file, atomically: true, encoding: .utf8)

    #expect(copilot.installation(in: file, helper: helper) == .stale)
    try copilot.install(into: file, helper: helper)
    #expect(copilot.installation(in: file, helper: helper) == .current)
  }

  @Test func aSharedFileMissingAnEventThisBuildAddedIsStaleNotAbsent() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent(".claude/settings.json")
    try FileManager.default.createDirectory(
      at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    let claude = AgentHookCatalogue.claude
    var settings = claude.adding(to: [:], helper: helper)
    var hooks = try #require(settings["hooks"] as? [String: Any])
    hooks["Notification"] = nil
    settings["hooks"] = hooks
    try JSONSerialization.data(withJSONObject: settings).write(to: file)

    #expect(claude.installation(in: file, helper: helper) == .stale)
  }

  @Test func aSharedFileIsCurrentOnlyWhileOurHooksAreWhatThisBuildWrites() throws {
    let codex = AgentHookCatalogue.codex
    let current = codex.adding(to: [:], helper: helper)
    #expect(codex.isCurrent(in: current, helper: helper))
    #expect(!codex.isCurrent(in: try staleCodexSettings(), helper: helper))

    var extra = try #require(current["hooks"] as? [String: Any])
    extra["Obsolete"] = extra["Stop"]
    #expect(!codex.isCurrent(in: ["hooks": extra], helper: helper))
  }

  @Test func installingOverAStaleInstallReplacesOursAndKeepsTheirs() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent(".codex/hooks.json")
    try FileManager.default.createDirectory(
      at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    var stale = try staleCodexSettings()
    var hooks = try #require(stale["hooks"] as? [String: Any])
    var stop = try #require(hooks["Stop"] as? [[String: Any]])
    stop.insert(["hooks": [["type": "command", "command": "~/bin/theirs.sh"]]], at: 0)
    hooks["Stop"] = stop
    stale["hooks"] = hooks
    try JSONSerialization.data(withJSONObject: stale).write(to: file)

    try AgentHookCatalogue.codex.install(into: file, helper: helper)

    let written = try AgentSettingsFile.read(file)
    #expect(AgentHookCatalogue.codex.isCurrent(in: written, helper: helper))
    let groups = try #require((written["hooks"] as? [String: Any])?["Stop"] as? [[String: Any]])
    #expect(groups.count == 2)
    #expect(
      (groups.first?["hooks"] as? [[String: Any]])?.first?["command"] as? String
        == "~/bin/theirs.sh")
  }

  @Test(arguments: AgentHookCatalogue.integrations.filter { !$0.isOursAlone })
  func aNullHooksKeyReadsAbsentInstallsCurrentAndRemovesBackToAbsent(
    agent: AgentHookIntegration
  ) throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let file = directory.appendingPathComponent("settings.json")
    let original = #"{"hooks":null,"model":"opus"}"#
    try original.write(to: file, atomically: true, encoding: .utf8)

    #expect(agent.installation(in: file, helper: helper) == .absent)
    try agent.remove(from: file)
    #expect(try String(contentsOf: file, encoding: .utf8) == original, "nothing of ours to take")

    try agent.install(into: file, helper: helper)
    #expect(agent.installation(in: file, helper: helper) == .current)

    try agent.remove(from: file)
    #expect(agent.installation(in: file, helper: helper) == .absent)
    #expect(try AgentSettingsFile.read(file)["model"] as? String == "opus")
    try agent.install(into: file, helper: helper)
    #expect(agent.installation(in: file, helper: helper) == .current)
  }

  /// What a build before the exit events' three-second timeout wrote.
  private func staleCodexSettings() throws -> [String: Any] {
    var settings = AgentHookCatalogue.codex.adding(to: [:], helper: helper)
    var hooks = try #require(settings["hooks"] as? [String: Any])
    var groups = try #require(hooks["Interrupt"] as? [[String: Any]])
    var entries = try #require(groups[0]["hooks"] as? [[String: Any]])
    entries[0]["timeout"] = 5
    groups[0]["hooks"] = entries
    hooks["Interrupt"] = groups
    settings["hooks"] = hooks
    return settings
  }
}
