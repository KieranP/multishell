import Foundation
import TestScratch
import Testing

@testable import MultishellCore

@Suite
struct AgentHookCatalogueTests: AgentHookFixtures {
  @Test func theCommandRunsTheHelperNamesTheAgentAndExitsCleanlyWithoutIt() {
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
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let fake = directory.appendingPathComponent("multishell")

    for ending in ["exit 3", "exit 2", "kill -TERM $$"] {
      try "#!/bin/sh\n\(ending)\n".write(to: fake, atomically: true, encoding: .utf8)
      try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fake.path)
      #expect(
        try status(of: AgentHookCatalogue.command(agent: "copilot", helper: fake.path)) == 0,
        "\(ending)")
    }

    try FileManager.default.removeItem(at: fake)
    #expect(
      try status(of: AgentHookCatalogue.command(agent: "copilot", helper: fake.path)) == 0,
      "missing")
  }

  /// Runs the hook line the way an agent would, and answers with its status.
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
    let old = "[ -x \"\(helper)\" ] && exec \"\(helper)\" claude-hook; exit 0"
    #expect(AgentHookCatalogue.isOurHook(old))
    #expect(
      AgentHookCatalogue.claude.isInstalled(in: ["hooks": groups(claudeEvents, command: old)]))
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

  @Test func everyIntegrationIsAnAgentTheCatalogueKnows() {
    for integration in AgentHookCatalogue.integrations {
      #expect(AgentCatalogue.agent(integration.id) != nil, "\(integration.id) is not launchable")
      #expect(AgentHookCatalogue.integration(integration.id)?.name == integration.name)
    }
    #expect(AgentHookCatalogue.integration("nonesuch") == nil)
    #expect(
      AgentHookCatalogue.integrations.map(\.id) == [
        "claude", "codex", "gemini", "copilot", "opencode",
      ])
  }

  @Test func everyHookedEventGetsOneEntryAndTheSnippetIsValidJSON() throws {
    let entries = AgentHookCatalogue.claude.entries(helper: helper)
    let hooks = try #require(entries["hooks"] as? [String: Any])
    #expect(Set(hooks.keys) == Set(AgentHookCatalogue.claude.events.map(\.name)))
    #expect(AgentHookCatalogue.claude.isInstalled(in: entries))

    let snippet = AgentHookCatalogue.claude.snippet(helper: helper)
    let parsed = try JSONSerialization.jsonObject(with: Data(snippet.utf8)) as? [String: Any]
    #expect(AgentHookCatalogue.claude.isInstalled(in: parsed ?? [:]))
    #expect(snippet.contains("\"timeout\" : 5"))
  }

  @Test func codexIsGivenNoTimeoutItWouldClampAndWarnAbout() throws {
    let hooks = try #require(
      AgentHookCatalogue.codex.entries(helper: helper)["hooks"] as? [String: Any])
    func timeout(_ event: String) -> Int? {
      let groups = hooks[event] as? [[String: Any]]
      return (groups?.first?["hooks"] as? [[String: Any]])?.first?["timeout"] as? Int
    }

    #expect(timeout("Interrupt") == 3)
    #expect(timeout("SessionEnd") == 3)
    for event in hooks.keys where !["Interrupt", "SessionEnd"].contains(event) {
      #expect(timeout(event) == 5, "\(event)")
    }
  }

  /// Gemini counts the timeout in milliseconds, and five seconds spelled as
  /// five would kill the helper before it reached the socket.
  @Test func geminiCountsTheTimeoutInMilliseconds() throws {
    #expect(AgentHookCatalogue.gemini.snippet(helper: helper).contains("\"timeout\" : 5000"))
    #expect(AgentHookCatalogue.claude.snippet(helper: helper).contains("\"timeout\" : 5"))
    #expect(AgentHookCatalogue.codex.snippet(helper: helper).contains("\"timeout\" : 5"))
  }

  @Test func theHelperReferenceGoesThroughHOME() {
    let reference = AgentHookCatalogue.helperReference
    #expect(
      reference.hasPrefix("$HOME/")
        || !reference.contains(FileManager.default.homeDirectoryForCurrentUser.path))
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
