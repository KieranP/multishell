import Foundation
import TestScratch
import Testing

@testable import MultishellCore

/// A file an older build wrote, told apart from what this build writes.
extension AgentHooksTests {
  @Test func oneReadAnswersInstalledAndCurrentAsTheTwoReadsDo() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let ours = directory.appendingPathComponent("hooks/multishell.json")
    let shared = directory.appendingPathComponent(".codex/hooks.json")
    try FileManager.default.createDirectory(
      at: shared.deletingLastPathComponent(), withIntermediateDirectories: true)
    let copilot = AgentHooks.copilot
    let codex = AgentHooks.codex

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
    let copilot = AgentHooks.copilot
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
    let claude = AgentHooks.claude
    var settings = claude.adding(to: [:], helper: helper)
    var hooks = try #require(settings["hooks"] as? [String: Any])
    hooks["Notification"] = nil
    settings["hooks"] = hooks
    try JSONSerialization.data(withJSONObject: settings).write(to: file)

    #expect(claude.installation(in: file, helper: helper) == .stale)
  }

  @Test func aSharedFileIsCurrentOnlyWhileOurHooksAreWhatThisBuildWrites() throws {
    let codex = AgentHooks.codex
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

    try AgentHooks.codex.install(into: file, helper: helper)

    let written = try HookSettingsFile.read(file)
    #expect(AgentHooks.codex.isCurrent(in: written, helper: helper))
    let groups = try #require((written["hooks"] as? [String: Any])?["Stop"] as? [[String: Any]])
    #expect(groups.count == 2)
    #expect(
      (groups.first?["hooks"] as? [[String: Any]])?.first?["command"] as? String
        == "~/bin/theirs.sh")
  }

  /// What a build before the exit events' three-second timeout wrote.
  private func staleCodexSettings() throws -> [String: Any] {
    var settings = AgentHooks.codex.adding(to: [:], helper: helper)
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
