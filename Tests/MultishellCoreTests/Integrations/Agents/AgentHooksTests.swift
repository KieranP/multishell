import Foundation
import TestScratch
import Testing

@testable import MultishellCore

/// The line a hook file runs, and what reads one back as ours.
@Suite
struct AgentHooksTests {
  let helper = "$HOME/Library/Application Support/Multishell/bin/multishell"

  func temporaryDirectory() -> URL {
    Scratch.path("hooks")
  }

  @Test func theCommandRunsTheHelperNamesTheAgentAndExitsCleanlyWithoutIt() {
    let command = AgentHooks.command(agent: "codex", helper: helper)
    #expect(
      command == "[ -x \"\(helper)\" ] && \"\(helper)\" agent-hook --agent codex; exit 0")
    #expect(!command.contains("="), "fish does not parse VAR=value")
    #expect(AgentHooks.isMultishellHook(command))
    #expect(!AgentHooks.isMultishellHook("curl -sf http://127.0.0.1:9/hook"))
  }

  /// Copilot denies a tool call when a preToolUse hook exits non-zero, and
  /// Claude blocks one on exit 2. Whatever becomes of the helper, the line
  /// answers 0: the worst a broken Multishell may do is stop the dots.
  @Test func aHelperThatDiesTakesTheDotsWithItAndNotTheToolCall() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let fake = directory.appendingPathComponent("multishell")

    for ending in ["exit 3", "exit 2", "kill -TERM $$"] {
      try "#!/bin/sh\n\(ending)\n".write(to: fake, atomically: true, encoding: .utf8)
      try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fake.path)
      #expect(
        try status(of: AgentHooks.command(agent: "copilot", helper: fake.path)) == 0, "\(ending)")
    }

    try FileManager.default.removeItem(at: fake)
    #expect(try status(of: AgentHooks.command(agent: "copilot", helper: fake.path)) == 0, "missing")
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

  /// The first hooks were installed with `claude-hook`, and settings files
  /// still say it: an install that did not recognise its own line would
  /// append a second one beside it.
  @Test func theLineAnOlderBuildWroteIsStillOurs() {
    let old = "[ -x \"\(helper)\" ] && exec \"\(helper)\" claude-hook; exit 0"
    #expect(AgentHooks.isMultishellHook(old))
    #expect(AgentHooks.claude.isInstalled(in: ["hooks": groups(claudeEvents, command: old)]))
  }

  @Test func everyIntegrationIsAnAgentTheCatalogueKnows() {
    for integration in AgentHooks.integrations {
      #expect(AgentCatalogue.agent(integration.id) != nil, "\(integration.id) is not launchable")
      #expect(AgentHooks.integration(for: integration.id)?.name == integration.name)
    }
    #expect(AgentHooks.integration(for: "aider") == nil)
    #expect(
      AgentHooks.integrations.map(\.id) == ["claude", "codex", "gemini", "copilot", "opencode"])
  }

  @Test func everyHookedEventGetsOneEntryAndTheSnippetIsValidJSON() throws {
    let entries = AgentHooks.claude.entries(helper: helper)
    let hooks = try #require(entries["hooks"] as? [String: Any])
    #expect(Set(hooks.keys) == Set(AgentHooks.claude.events.map(\.name)))
    #expect(AgentHooks.claude.isInstalled(in: entries))

    let snippet = AgentHooks.claude.snippet(helper: helper)
    let parsed = try JSONSerialization.jsonObject(with: Data(snippet.utf8)) as? [String: Any]
    #expect(AgentHooks.claude.isInstalled(in: parsed ?? [:]))
    #expect(snippet.contains("\"timeout\" : 5"))
  }

  /// Gemini counts the timeout in milliseconds, and five seconds spelled as
  /// five would kill the helper before it reached the socket.
  @Test func geminiCountsTheTimeoutInMilliseconds() throws {
    #expect(AgentHooks.gemini.snippet(helper: helper).contains("\"timeout\" : 5000"))
    #expect(AgentHooks.claude.snippet(helper: helper).contains("\"timeout\" : 5"))
    #expect(AgentHooks.codex.snippet(helper: helper).contains("\"timeout\" : 5"))
  }

  @Test func theHelperReferenceGoesThroughHOME() {
    let reference = AgentHooks.helperReference
    #expect(
      reference.hasPrefix("$HOME/")
        || !reference.contains(FileManager.default.homeDirectoryForCurrentUser.path))
    #expect(reference.hasSuffix("/bin/multishell"))
  }

  private var claudeEvents: [String] { AgentHooks.claude.events.map(\.name) }

  private func groups(_ events: [String], command: String) -> [String: Any] {
    var hooks: [String: Any] = [:]
    for event in events {
      hooks[event] = [["hooks": [["type": "command", "command": command]]]]
    }
    return hooks
  }
}
