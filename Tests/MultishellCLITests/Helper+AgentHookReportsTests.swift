import Foundation
import TestScratch
import Testing

@testable import MultishellCore
@testable import MultishellProcess

/// The built helper as each agent's hook line runs it.
@Suite(.serialized)
struct HelperAgentHookReportsTests {
  @Test func anAgentHookPayloadBecomesTheMatchingReport() async throws {
    let listener = try ReportListener()
    defer { listener.stop() }
    let recorder = listener.recorder
    let session = UUID()
    let payload = #"""
      {"session_id":"s","cwd":"/w/repo","hook_event_name":"Notification",
       "message":"Claude needs your permission to use Bash","notification_type":"permission_prompt"}
      """#

    let output = try await HelperBinary.run(
      ["claude-hook"],
      environment: [
        "MULTISHELL_SOCKET": listener.path.path, "MULTISHELL_SESSION": session.uuidString,
      ],
      stdin: payload,
    )

    #expect(output.succeeded)
    #expect(output.standardOutput.isEmpty, "Claude reads a hook's stdout")
    try await waitUntil { !recorder.received.isEmpty }
    let report = SessionStateReport.parse(recorder.received.first ?? "")
    #expect(report?.state == .attention)
    #expect(report?.sessionID == session)
    #expect(report?.message == "Claude needs your permission to use Bash")
    #expect((report?.pid ?? 0) > 0, "the parent's pid, for staleness checks")
    #expect(report?.agentID == AgentCatalogue.claudeID, "who is at that prompt")
  }

  @Test func anEventThatSaysNothingAndAMissingAppBothExitZeroInSilence() async throws {
    let listener = try ReportListener()
    defer { listener.stop() }
    let ignored = try await HelperBinary.run(
      ["claude-hook"],
      environment: ["MULTISHELL_SOCKET": listener.path.path],
      stdin: #"{"hook_event_name":"PreCompact","cwd":"/w"}"#,
    )
    #expect(ignored.succeeded && ignored.standardOutput.isEmpty && ignored.standardError.isEmpty)
    let orphan = try await HelperBinary.run(
      ["claude-hook"],
      environment: ["MULTISHELL_SOCKET": "/tmp/ms-nobody.sock"],
      stdin: #"{"hook_event_name":"Stop","cwd":"/w"}"#,
    )
    #expect(orphan.succeeded && orphan.standardError.isEmpty)
    try await expectOnlyTheBarrier(on: listener)
  }

  @Test func aGeminiTurnThatHasEndedIsDoneWithGeminiAtThePrompt() async throws {
    let listener = try ReportListener()
    defer { listener.stop() }
    let gemini = try await HelperBinary.run(
      ["agent-hook", "--agent", "gemini"],
      environment: ["MULTISHELL_SOCKET": listener.path.path],
      stdin: #"{"hook_event_name":"AfterAgent","cwd":"/w/repo"}"#,
    )
    #expect(gemini.succeeded && gemini.standardOutput.isEmpty)
    try await waitUntil { listener.recorder.received.count == 1 }
    let report = SessionStateReport.parse(listener.recorder.received.last ?? "")
    #expect(report?.state == .done)
    #expect(report?.agentID == "gemini")
    #expect(report?.workingDirectory == "/w/repo")
  }

  /// Claude says one prompt twice: the notification speaks and carries the
  /// wording, so the request moves the dot without a banner.
  @Test func claudesPermissionRequestMovesTheDotSilentlyAndWithoutWords() async throws {
    let listener = try ReportListener()
    defer { listener.stop() }
    let request = try await HelperBinary.run(
      ["agent-hook", "--agent", "claude"],
      environment: [
        "MULTISHELL_SOCKET": listener.path.path, "MULTISHELL_SESSION": UUID().uuidString,
      ],
      stdin: #"""
        {"hook_event_name":"PermissionRequest","cwd":"/w/repo",
         "permission_mode":"default","tool_name":"Bash"}
        """#,
    )
    #expect(request.succeeded && request.standardOutput.isEmpty)
    try await waitUntil { listener.recorder.received.count == 1 }
    let report = SessionStateReport.parse(listener.recorder.received.last ?? "")
    #expect(report?.state == .attention)
    #expect(report?.isSilent == true)
    #expect(report?.message == nil)
  }

  @Test func aPermissionRequestAClassifierAnswersSaysNothing() async throws {
    let listener = try ReportListener()
    defer { listener.stop() }
    let classifier = try await HelperBinary.run(
      ["agent-hook", "--agent", "claude"],
      environment: ["MULTISHELL_SOCKET": listener.path.path],
      stdin: #"""
        {"hook_event_name":"PermissionRequest","cwd":"/w/repo","permission_mode":"auto"}
        """#,
    )
    #expect(classifier.succeeded && classifier.standardError.isEmpty)
    try await expectOnlyTheBarrier(on: listener)
  }

  private func expectOnlyTheBarrier(on listener: ReportListener) async throws {
    #expect(try await listener.linesUpToABarrier().count == 1)
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
      at: settings.deletingLastPathComponent(),
      withIntermediateDirectories: true,
    )
    let environment = [
      "MULTISHELL_SOCKET": listener.path.path, "GEMINI_CLI_HOME": home.path,
      "GEMINI_CLI_SYSTEM_SETTINGS_PATH": home.appendingPathComponent("system.json").path,
    ]
    let shell = try WaitingShell(marker: "_bgpids_file=/tmp/gemini-shell-test/bgpids.tmp")
    defer { shell.terminate() }
    func hook(_ agent: String, _ payload: String) async throws {
      let output = try await HelperBinary.run(
        ["agent-hook", "--agent", agent],
        environment: environment,
        stdin: payload,
      )
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
    #expect(reports[0]?.backgroundShells?.contains(shell.pid) == true)
    #expect(reports[0]?.resumesAfterWorkers == nil, "a shell's end is silent by default")
    #expect(reports[1]?.backgroundShells == nil, "only a Done looks")
    #expect(reports[2]?.backgroundShells == nil, "Claude's own Stop lists its shells")
    #expect(reports[3]?.resumesAfterWorkers == true)
  }
}
