import Foundation
import TestScratch
import Testing

@testable import MultishellCore
@testable import MultishellProcess

/// The built helper as each agent's hook line runs it, and the hooks commands
/// a person types.
@Suite(.serialized)
struct HelperAgentHooksTests {
  @Test func anAgentHookPayloadBecomesTheMatchingReportAndAlwaysExitsZero() async throws {
    let listener = try ReportListener()
    defer { listener.stop() }
    let path = listener.path
    let recorder = listener.recorder
    let session = UUID()
    let payload = #"""
      {"session_id":"s","cwd":"/w/repo","hook_event_name":"Notification",
       "message":"Claude needs your permission to use Bash","notification_type":"permission_prompt"}
      """#

    let output = try await HelperBinary.run(
      ["claude-hook"],
      environment: ["MULTISHELL_SOCKET": path.path, "MULTISHELL_SESSION": session.uuidString],
      stdin: payload)

    #expect(output.succeeded)
    #expect(output.standardOutput.isEmpty, "Claude reads a hook's stdout")
    try await waitUntil { !recorder.received.isEmpty }
    let report = SessionStateReport.parse(recorder.received.first ?? "")
    #expect(report?.state == .attention)
    #expect(report?.sessionID == session)
    #expect(report?.message == "Claude needs your permission to use Bash")
    #expect((report?.pid ?? 0) > 0, "the parent's pid, for staleness checks")
    #expect(report?.agent == AgentCatalogue.claudeID, "who is at that prompt")

    // An event that says nothing, and no app at all: both exit 0 in silence.
    let ignored = try await HelperBinary.run(
      ["claude-hook"], environment: ["MULTISHELL_SOCKET": path.path],
      stdin: #"{"hook_event_name":"PreCompact","cwd":"/w"}"#)
    #expect(ignored.succeeded && ignored.standardOutput.isEmpty && ignored.standardError.isEmpty)
    let orphan = try await HelperBinary.run(
      ["claude-hook"], environment: ["MULTISHELL_SOCKET": "/tmp/ms-nobody.sock"],
      stdin: #"{"hook_event_name":"Stop","cwd":"/w"}"#)
    #expect(orphan.succeeded && orphan.standardError.isEmpty)
    try await Task.sleep(for: .milliseconds(200))
    #expect(recorder.received.count == 1)

    // The same line for an agent whose events are named its own way: a
    // Gemini turn that has ended is Done, and Gemini is at that prompt.
    let gemini = try await HelperBinary.run(
      ["agent-hook", "--agent", "gemini"], environment: ["MULTISHELL_SOCKET": path.path],
      stdin: #"{"hook_event_name":"AfterAgent","cwd":"/w/repo"}"#)
    #expect(gemini.succeeded && gemini.standardOutput.isEmpty)
    try await waitUntil { recorder.received.count == 2 }
    let second = SessionStateReport.parse(recorder.received.last ?? "")
    #expect(second?.state == .done)
    #expect(second?.agent == "gemini")
    #expect(second?.cwd == "/w/repo")

    // Claude says one prompt twice. The request moves the dot without a banner,
    // and its notification above speaks and carries the wording.
    let request = try await HelperBinary.run(
      ["agent-hook", "--agent", "claude"],
      environment: ["MULTISHELL_SOCKET": path.path, "MULTISHELL_SESSION": session.uuidString],
      stdin: #"""
        {"hook_event_name":"PermissionRequest","cwd":"/w/repo",
         "permission_mode":"default","tool_name":"Bash"}
        """#)
    #expect(request.succeeded && request.standardOutput.isEmpty)
    try await waitUntil { recorder.received.count == 3 }
    let third = SessionStateReport.parse(recorder.received.last ?? "")
    #expect(third?.state == .attention)
    #expect(third?.silent == true)
    #expect(third?.message == nil)

    // The mode where a classifier answers the prompt: nobody is waiting,
    // so nothing is said at all.
    let classifier = try await HelperBinary.run(
      ["agent-hook", "--agent", "claude"], environment: ["MULTISHELL_SOCKET": path.path],
      stdin: #"""
        {"hook_event_name":"PermissionRequest","cwd":"/w/repo","permission_mode":"auto"}
        """#)
    #expect(classifier.succeeded && classifier.standardError.isEmpty)
    try await Task.sleep(for: .milliseconds(200))
    #expect(recorder.received.count == 3)
  }

  /// Here the test process stands in for Gemini, the helper's first
  /// non-shell ancestor, and the marked shell for one its shell tool left running.
  @Test func geminisDoneNamesTheShellsItLeftRunningAndResumesOnlyWhenSetTo() async throws {
    let listener = try ReportListener()
    defer { listener.stop() }
    let recorder = listener.recorder
    let home = Scratch.path("gemini-home")
    defer { Scratch.remove(home) }
    let settings = home.appendingPathComponent(".gemini/settings.json")
    try FileManager.default.createDirectory(
      at: settings.deletingLastPathComponent(), withIntermediateDirectories: true)
    let environment = [
      "MULTISHELL_SOCKET": listener.path.path, "GEMINI_CLI_HOME": home.path,
      "GEMINI_CLI_SYSTEM_SETTINGS_PATH": home.appendingPathComponent("system.json").path,
    ]
    let shell = Process()
    shell.executableURL = URL(fileURLWithPath: "/bin/sh")
    shell.arguments = ["-c", "read line # _bgpids_file=/tmp/gemini-shell-test/bgpids.tmp"]
    shell.standardInput = Pipe()
    try shell.run()
    defer { shell.terminate() }
    func hook(_ agent: String, _ payload: String) async throws {
      let output = try await HelperBinary.run(
        ["agent-hook", "--agent", agent], environment: environment, stdin: payload)
      #expect(output.succeeded && output.standardOutput.isEmpty)
    }

    try await hook("gemini", #"{"hook_event_name":"AfterAgent","cwd":"/w/repo"}"#)
    try await hook("gemini", #"{"hook_event_name":"BeforeTool","cwd":"/w/repo"}"#)
    try await hook("claude", #"{"hook_event_name":"Stop","cwd":"/w/repo"}"#)
    try #"""
    {
      // Both are needed before a shell's end starts a turn.
      "experimental": { "modelSteering": true },
      "tools": { "shell": { "backgroundCompletionBehavior": "inject" } }
    }
    """#.write(to: settings, atomically: true, encoding: .utf8)
    try await hook("gemini", #"{"hook_event_name":"AfterAgent","cwd":"/w/repo"}"#)

    try await waitUntil { recorder.received.count == 4 }
    let reports = recorder.received.map(SessionStateReport.parse)
    #expect(reports[0]?.state == .done)
    #expect(reports[0]?.backgroundShells?.contains(shell.processIdentifier) == true)
    #expect(reports[0]?.resumesAfterWorkers == nil, "a shell's end is silent by default")
    #expect(reports[1]?.backgroundShells == nil, "only a Done looks")
    #expect(reports[2]?.backgroundShells == nil, "Claude's own Stop lists its shells")
    #expect(reports[3]?.resumesAfterWorkers == true)
  }

  @Test func printingTheHooksGivesTheSnippetWithoutTouchingAnyFile() async throws {
    let home = try Scratch.directory("home")
    defer { Scratch.remove(home) }
    let environment = ["HOME": home.path]

    let claude = try await HelperBinary.run(
      ["install-agent-hooks", "--agent", "claude", "--print"], environment: environment)
    #expect(claude.succeeded)
    let object =
      try JSONSerialization.jsonObject(with: Data(claude.standardOutput.utf8)) as? [String: Any]
    let hooks = object?["hooks"] as? [String: Any] ?? [:]
    #expect(Set(hooks.keys) == Set(AgentHookCatalogue.claude.events.map(\.name)))
    #expect(AgentHookCatalogue.claude.holdsAnyOfOurHooks(object ?? [:]))

    let copilot = try await HelperBinary.run(
      ["install-agent-hooks", "--agent", "copilot", "--print"], environment: environment)
    #expect(copilot.succeeded)
    let file =
      try JSONSerialization.jsonObject(with: Data(copilot.standardOutput.utf8)) as? [String: Any]
    #expect(file?["version"] as? Int == 1)

    let plugin = try await HelperBinary.run(
      ["install-agent-hooks", "--agent", "opencode", "--print"], environment: environment)
    #expect(plugin.succeeded && plugin.standardOutput.contains("MultishellPlugin"))

    let unknown = try await HelperBinary.run(
      ["install-agent-hooks", "--agent", "nonesuch"], environment: environment)
    #expect(unknown.status == 2 && unknown.standardError.contains("no hooks for nonesuch"))
    #expect(try FileManager.default.contentsOfDirectory(atPath: home.path).isEmpty)
  }

  @Test func aTypedHooksCommandRefusesAMisspeltOrMissingAgent() async throws {
    let home = try Scratch.directory("home")
    defer { Scratch.remove(home) }
    let environment = ["HOME": home.path]

    let misspelt = try await HelperBinary.run(
      ["install-agent-hooks", "--agnet", "codex"], environment: environment)
    #expect(misspelt.status == 2, "\(misspelt.standardOutput)")
    #expect(misspelt.standardError.contains("--agnet"))

    let missing = try await HelperBinary.run(["remove-agent-hooks"], environment: environment)
    #expect(missing.status == 2)
    #expect(missing.standardError.contains("--agent"))

    let stray = try await HelperBinary.run(
      ["install-agent-hooks", "--agent", "codex", "--print", "extra"], environment: environment)
    #expect(stray.status == 2)
    #expect(try FileManager.default.contentsOfDirectory(atPath: home.path).isEmpty)
  }

  @Test func hooksAreInstalledAndRemovedUnderTheHomeTheHelperIsGiven() async throws {
    let home = try Scratch.directory("home")
    defer { Scratch.remove(home) }
    let file = home.appendingPathComponent(".codex/hooks.json")

    let installed = try await HelperBinary.run(
      ["install-agent-hooks", "--agent", "codex"], environment: ["HOME": home.path])
    #expect(installed.succeeded, "\(installed.standardError)")
    #expect(AgentHookCatalogue.codex.installation(in: file) != .absent)

    let removed = try await HelperBinary.run(
      ["remove-agent-hooks", "--agent", "codex"], environment: ["HOME": home.path])
    #expect(removed.succeeded, "\(removed.standardError)")
    #expect(AgentHookCatalogue.codex.installation(in: file) == .absent)
  }
}
