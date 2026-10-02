import Foundation
import TestScratch
import Testing

@testable import MultishellCore

@Suite
struct AgentHookCatalogueHookLineTests: AgentHookFixtures {
  @Test func theCommandGuardsOnTheHelperNamesTheAgentAndEndsInExitZero() {
    let command = AgentHookCatalogue.command(agent: "codex", helper: helper)
    #expect(
      command == "[ -x \"\(helper)\" ] && \"\(helper)\" agent-hook --agent codex; exit 0")
    #expect(!command.contains("="), "fish does not parse VAR=value")
    #expect(AgentHookCatalogue.isOurHook(command))
    #expect(!AgentHookCatalogue.isOurHook("curl -sf http://127.0.0.1:9/hook"))
  }

  /// Copilot denies a tool call when a preToolUse hook exits non-zero, and Claude blocks one on
  /// exit 2, so the line answers 0 whatever becomes of the helper.
  @Test func aHelperThatDiesTakesTheDotsWithItAndNotTheToolCall() throws {
    let directory = try Scratch.directory("hooks")
    defer { Scratch.remove(directory) }
    let fake = directory.appendingPathComponent("multishell")

    for ending in ["exit 3", "exit 2", "kill -TERM $$"] {
      try Scratch.script(ending, at: fake)
      #expect(
        try status(of: AgentHookCatalogue.command(agent: "copilot", helper: fake.path)) == 0,
        "\(ending)")
    }

    try FileManager.default.removeItem(at: fake)
    #expect(
      try status(of: AgentHookCatalogue.command(agent: "copilot", helper: fake.path)) == 0,
      "missing")
  }

  private func status(of line: String) throws -> Int32 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = ["-c", line]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try process.run()
    process.waitUntilExit()
    return process.terminationStatus
  }

  /// Settings files still hold the `claude-hook` line the first builds wrote, and an install that
  /// missed it would append a second one beside it.
  @Test func theLineAnOlderBuildWroteIsStillOurs() {
    #expect(AgentHookCatalogue.isOurHook(legacyClaudeHookLine))
    #expect(
      AgentHookCatalogue.claude.hasOurHookUnderEveryEvent(in: [
        "hooks": groups(claudeEvents, command: legacyClaudeHookLine)
      ]))
  }

  /// A substring test ate a hook whose script merely spelled both names, and
  /// skipped the event it was found under.
  @Test func aUsersOwnHookThatMerelySpellsTheNamesIsNotOurs() {
    let theirs = [
      "~/bin/multishell-agent-hook-logger",
      "$HOME/bin/log-multishell-agent-hook --verbose",
      "echo multishell agent-hooked",
      "notify multishell_agent_hook",
      "run claude-hooks",
    ]
    for command in theirs {
      #expect(!AgentHookCatalogue.isOurHook(command), "\(command.debugDescription)")
    }
  }

  @Test func theHelperReferenceGoesThroughHOME() {
    let reference = AgentHookCatalogue.helperReference
    #expect(reference.hasPrefix("$HOME/"), "\(reference)")
    #expect(reference.hasSuffix("/bin/multishell"))
  }

  private var claudeEvents: [String] { AgentHookCatalogue.claude.events.map(\.name) }

  private func groups(_ events: [String], command: String) -> [String: Any] {
    var hooks: [String: Any] = [:]
    for event in events {
      hooks[event] = [["hooks": [["type": "command", "command": command]]]]
    }
    return hooks
  }
}
