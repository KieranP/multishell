import Foundation
import MultishellProcess
import TestScratch
import Testing

@testable import MultishellCore

/// The built `multishell` binary against a real socket: what a hook does,
/// end to end, minus Claude itself.
@Suite(.serialized)
struct HelperTests {
  private func run(
    _ arguments: [String], environment: [String: String] = [:], stdin: String? = nil,
    via executable: URL? = nil
  ) async throws -> ProcessOutput {
    var env = environment
    env["PATH"] = ProcessInfo.processInfo.environment["PATH"]
    let runner = ProcessRunner()
    guard let stdin else {
      return try await runner.capture(
        executable ?? HelperBinary.require(), arguments, in: URL(fileURLWithPath: "/tmp"),
        environment: env)
    }
    // Stdin through a shell pipe, since the runner gives children /dev/null.
    let quoted = ShellQuoting.quote(stdin)
    let command =
      "printf '%s' \(quoted) | \(ShellQuoting.quote(try HelperBinary.require().path)) "
      + ShellQuoting.commandLine(arguments)
    return try await runner.capture(
      URL(fileURLWithPath: "/bin/sh"), ["-c", command], in: URL(fileURLWithPath: "/tmp"),
      environment: env)
  }

  @Test func stateReachesTheServerWithTheSessionFromTheEnvironment() async throws {
    let listener = try ReportListener()
    defer { listener.stop() }
    let path = listener.path
    let recorder = listener.recorder
    let session = UUID()

    let output = try await run(
      ["state", "running", "--pid", "4242"],
      environment: [
        "MULTISHELL_SOCKET": path.path, "MULTISHELL_SESSION": session.uuidString,
        "MULTISHELL_WORKTREE": "/w/repo",
      ])

    #expect(output.succeeded, "\(output.standardError)")
    try await waitUntil { !recorder.received.isEmpty }
    let report = SessionStateReport.parse(recorder.received.first ?? "")
    #expect(report?.state == .running)
    #expect(report?.sessionID == session)
    #expect(report?.cwd == "/w/repo")
    #expect(report?.pid == 4242)
    #expect(report?.version == SessionStateReport.protocolVersion)
  }

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

    let output = try await run(
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
    let ignored = try await run(
      ["claude-hook"], environment: ["MULTISHELL_SOCKET": path.path],
      stdin: #"{"hook_event_name":"PreCompact","cwd":"/w"}"#)
    #expect(ignored.succeeded && ignored.standardOutput.isEmpty && ignored.standardError.isEmpty)
    let orphan = try await run(
      ["claude-hook"], environment: ["MULTISHELL_SOCKET": "/tmp/ms-nobody.sock"],
      stdin: #"{"hook_event_name":"Stop","cwd":"/w"}"#)
    #expect(orphan.succeeded && orphan.standardError.isEmpty)
    try await Task.sleep(for: .milliseconds(200))
    #expect(recorder.received.count == 1)

    // The same line for an agent whose events are named its own way: a
    // Gemini turn that has ended is Done, and Gemini is at that prompt.
    let gemini = try await run(
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
    let request = try await run(
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
    let classifier = try await run(
      ["agent-hook", "--agent", "claude"], environment: ["MULTISHELL_SOCKET": path.path],
      stdin: #"""
        {"hook_event_name":"PermissionRequest","cwd":"/w/repo","permission_mode":"auto"}
        """#)
    #expect(classifier.succeeded && classifier.standardError.isEmpty)
    try await Task.sleep(for: .milliseconds(200))
    #expect(recorder.received.count == 3)
  }

  /// Here the test process stands in for Claude, the helper's first
  /// non-shell ancestor, and the marked shell for a task it backgrounded.
  @Test func claudesStopNamesTheBackgroundShellsItLeftRunning() async throws {
    let listener = try ReportListener()
    defer { listener.stop() }
    let path = listener.path
    let recorder = listener.recorder
    let shell = Process()
    shell.executableURL = URL(fileURLWithPath: "/bin/sh")
    shell.arguments = ["-c", "read line # ~/.claude/shell-snapshots/snapshot-zsh-test.sh"]
    shell.standardInput = Pipe()
    try shell.run()
    defer { shell.terminate() }

    let stop = try await run(
      ["agent-hook", "--agent", "claude"], environment: ["MULTISHELL_SOCKET": path.path],
      stdin: #"{"hook_event_name":"Stop","cwd":"/w/repo"}"#)
    #expect(stop.succeeded && stop.standardOutput.isEmpty)
    let tool = try await run(
      ["agent-hook", "--agent", "claude"], environment: ["MULTISHELL_SOCKET": path.path],
      stdin: #"{"hook_event_name":"PreToolUse","cwd":"/w/repo"}"#)
    #expect(tool.succeeded)
    let gemini = try await run(
      ["agent-hook", "--agent", "gemini"], environment: ["MULTISHELL_SOCKET": path.path],
      stdin: #"{"hook_event_name":"AfterAgent","cwd":"/w/repo"}"#)
    #expect(gemini.succeeded)

    try await waitUntil { recorder.received.count == 3 }
    let reports = recorder.received.map(SessionStateReport.parse)
    #expect(reports[0]?.state == .done)
    #expect(reports[0]?.backgroundShells?.contains(shell.processIdentifier) == true)
    #expect(reports[0]?.resumesAfterWorkers == true, "Claude takes a turn when they end")
    #expect(reports[1]?.backgroundShells == nil, "only a Stop looks")
    #expect(reports[1]?.resumesAfterWorkers == nil)
    #expect(reports[2]?.backgroundShells == nil, "and only for an agent with a signature")
    #expect(reports[2]?.resumesAfterWorkers == nil)
  }

  /// Any tool can say which agent is at the prompt, the way Claude's hooks
  /// do, so the app writes a dropped file the way that agent reads one.
  @Test func stateCanNameTheAgentAtThePrompt() async throws {
    let listener = try ReportListener()
    defer { listener.stop() }
    let path = listener.path
    let recorder = listener.recorder

    let output = try await run(
      ["state", "running", "--agent", "codex"], environment: ["MULTISHELL_SOCKET": path.path])
    #expect(output.succeeded, "\(output.standardError)")

    try await waitUntil { !recorder.received.isEmpty }
    #expect(SessionStateReport.parse(recorder.received.first ?? "")?.agent == "codex")
  }

  /// OpenCode's plugin has no payload to hand over and names a worker by flags.
  /// A phase without a worker, or a worker without a phase, is a usage error.
  @Test func stateCanNameASubagent() async throws {
    let listener = try ReportListener()
    defer { listener.stop() }
    let path = listener.path
    let recorder = listener.recorder

    let output = try await run(
      [
        "state", "running", "--agent", "opencode", "--subagent", "ses_1", "--subagent-phase",
        "working", "--subagent-type", "explore",
      ], environment: ["MULTISHELL_SOCKET": path.path])
    #expect(output.succeeded, "\(output.standardError)")
    try await waitUntil { !recorder.received.isEmpty }
    let report = SessionStateReport.parse(recorder.received.first ?? "")
    #expect(report?.subagent == SubagentReport(id: "ses_1", type: "explore", phase: .working))

    let prompt = try await run(
      ["state", "running", "--agent", "opencode", "--new-turn", "true"],
      environment: ["MULTISHELL_SOCKET": path.path])
    #expect(prompt.succeeded, "\(prompt.standardError)")
    try await waitUntil { recorder.received.count == 2 }
    #expect(SessionStateReport.parse(recorder.received.last ?? "")?.startsTurn == true)

    let halfSaid = try await run(
      ["state", "running", "--subagent", "ses_1"], environment: ["MULTISHELL_SOCKET": path.path])
    #expect(halfSaid.status == 2)
    #expect(halfSaid.standardError.contains("--subagent-phase"))
    let phaseAlone = try await run(
      ["state", "running", "--subagent-phase", "ended"],
      environment: ["MULTISHELL_SOCKET": path.path])
    #expect(phaseAlone.status == 2)
    let typeAlone = try await run(
      ["state", "running", "--subagent-type", "explore"],
      environment: ["MULTISHELL_SOCKET": path.path])
    #expect(typeAlone.status == 2)
    #expect(typeAlone.standardError.contains("--subagent"))

    // A report the server has read is the barrier: anything the three usage
    // errors had sent would be on the line before it.
    let after = try await run(
      ["state", "done", "--agent", "opencode"], environment: ["MULTISHELL_SOCKET": path.path])
    #expect(after.succeeded, "\(after.standardError)")
    try await waitUntil { recorder.received.count == 3 }
    #expect(
      SessionStateReport.parse(recorder.received.last ?? "")?.state == .done,
      "the barrier is the third line, so nothing the usage errors sent is behind it")
    #expect(recorder.received.count == 3, "no half-said worker reached the app")
  }

  /// The pid reported is the program that ran the hook, past any shells
  /// between: here the test process, two `sh -c` layers up.
  @Test func thePidReportedIsTheFirstNonShellAncestor() async throws {
    let listener = try ReportListener()
    defer { listener.stop() }
    let path = listener.path
    let recorder = listener.recorder

    let inner = "\(ShellQuoting.quote(try HelperBinary.require().path)) state running"
    let output = try await run(
      ["-c", "/bin/sh -c \(ShellQuoting.quote(inner))"],
      environment: ["MULTISHELL_SOCKET": path.path], via: URL(fileURLWithPath: "/bin/sh"))
    #expect(output.succeeded, "\(output.standardError)")

    try await waitUntil { !recorder.received.isEmpty }
    let report = SessionStateReport.parse(recorder.received.first ?? "")
    #expect(report?.pid == ProcessInfo.processInfo.processIdentifier)
  }

  /// At a prompt in the app's own tab the first non-shell ancestor is the app,
  /// whose pid never goes, so the walk names the shell underneath instead.
  @Test func thePidReportedStopsShortOfTheAppItself() async throws {
    let listener = try ReportListener()
    defer { listener.stop() }
    let path = listener.path
    let recorder = listener.recorder

    let me = ProcessInfo.processInfo.processIdentifier
    let inner = "\(ShellQuoting.quote(try HelperBinary.require().path)) state running"
    let output = try await run(
      ["-c", "echo $$; /bin/sh -c \(ShellQuoting.quote(inner))"],
      environment: ["MULTISHELL_SOCKET": path.path, "MULTISHELL_APP_PID": String(me)],
      via: URL(fileURLWithPath: "/bin/sh"))
    #expect(output.succeeded, "\(output.standardError)")
    let outer = Int32(output.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines))

    try await waitUntil { !recorder.received.isEmpty }
    let report = SessionStateReport.parse(recorder.received.first ?? "")
    #expect(report?.pid == outer, "the shell nearest the app")
    #expect(report?.pid != me)
  }

  @Test func commandStartedAndFinishedMapToRunningDoneAndFailed() async throws {
    let listener = try ReportListener()
    defer { listener.stop() }
    let path = listener.path
    let recorder = listener.recorder
    let session = UUID()
    let env = [
      "MULTISHELL_SOCKET": path.path, "MULTISHELL_SESSION": session.uuidString,
      "MULTISHELL_WORKTREE": "/w/repo",
    ]

    #expect(try await run(["command-started", "--pid", "4242"], environment: env).succeeded)
    #expect(
      try await run(["command-finished", "--exit", "0", "--duration", "3.5"], environment: env)
        .succeeded)
    #expect(try await run(["command-finished", "--exit", "2"], environment: env).succeeded)
    #expect(try await run(["command-finished", "--exit", "130"], environment: env).succeeded)

    try await waitUntil { recorder.received.count == 4 }
    let states = recorder.received.compactMap { SessionStateReport.parse($0)?.state }
    #expect(states == [.running, .done, .error, .done], "signals are not failures")
    #expect(SessionStateReport.parse(recorder.received[1])?.duration == 3.5)
    #expect(SessionStateReport.parse(recorder.received[2])?.duration == nil)
    #expect(SessionStateReport.parse(recorder.received[0])?.sessionID == session)
    #expect(SessionStateReport.parse(recorder.received[0])?.cwd == "/w/repo")
    #expect(
      SessionStateReport.parse(recorder.received[0])?.pid == 4242,
      "the shell's pid, so a shell that exits mid-command clears its Working")
    #expect(
      recorder.received.allSatisfy { SessionStateReport.parse($0)?.isShell == true },
      "both are the shell's own, which is what may take an agent's mark back")

    #expect(try await run(["state", "running"], environment: env).succeeded)
    try await waitUntil { recorder.received.count == 5 }
    #expect(
      SessionStateReport.parse(recorder.received[4])?.isShell == nil,
      "and a script of the user's is not, whatever state it reports")
  }

  @Test func stateWithNobodyListeningFailsLoudly() async throws {
    let output = try await run(
      ["state", "done"], environment: ["MULTISHELL_SOCKET": "/tmp/ms-nobody.sock"])
    #expect(output.status == 1)
    #expect(output.standardError.contains("could not reach Multishell"))
  }

  @Test func usageErrorsExitTwo() async throws {
    #expect(try await run([]).status == 2)
    #expect(try await run(["state", "sleeping"]).status == 2)
    #expect(try await run(["state", "done", "--bogus"]).status == 2)
    #expect(try await run(["frobnicate"]).status == 2)
    let version = try await run(["--version"])
    #expect(version.succeeded && version.standardOutput.contains("protocol version 1"))
  }

  @Test func printingTheHooksGivesTheSnippetWithoutTouchingAnyFile() async throws {
    let claude = try await run(["install-agent-hooks", "--agent", "claude", "--print"])
    #expect(claude.succeeded)
    let object =
      try JSONSerialization.jsonObject(with: Data(claude.standardOutput.utf8)) as? [String: Any]
    #expect(AgentHooks.claude.isInstalled(in: object ?? [:]))

    let copilot = try await run(["install-agent-hooks", "--agent", "copilot", "--print"])
    #expect(copilot.succeeded)
    let file =
      try JSONSerialization.jsonObject(with: Data(copilot.standardOutput.utf8)) as? [String: Any]
    #expect(file?["version"] as? Int == 1)

    let plugin = try await run(["install-agent-hooks", "--agent", "opencode", "--print"])
    #expect(plugin.succeeded && plugin.standardOutput.contains("MultishellPlugin"))

    let unknown = try await run(["install-agent-hooks", "--agent", "nonesuch"])
    #expect(unknown.status == 2 && unknown.standardError.contains("no hooks for nonesuch"))
  }

  @Test func aTypedHooksCommandRefusesAMisspeltOrMissingAgent() async throws {
    let home = try Scratch.directory("home")
    defer { Scratch.remove(home) }
    let environment = ["HOME": home.path]

    let misspelt = try await run(
      ["install-agent-hooks", "--agnet", "codex"], environment: environment)
    #expect(misspelt.status == 2, "\(misspelt.standardOutput)")
    #expect(misspelt.standardError.contains("--agnet"))

    let missing = try await run(["remove-agent-hooks"], environment: environment)
    #expect(missing.status == 2)
    #expect(missing.standardError.contains("--agent"))

    let stray = try await run(
      ["install-agent-hooks", "--agent", "codex", "--print", "extra"], environment: environment)
    #expect(stray.status == 2)
    #expect(try FileManager.default.contentsOfDirectory(atPath: home.path).isEmpty)
  }

  @Test func hooksAreInstalledAndRemovedUnderTheHomeTheHelperIsGiven() async throws {
    let home = try Scratch.directory("home")
    defer { Scratch.remove(home) }
    let file = home.appendingPathComponent(".codex/hooks.json")

    let installed = try await run(
      ["install-agent-hooks", "--agent", "codex"], environment: ["HOME": home.path])
    #expect(installed.succeeded, "\(installed.standardError)")
    #expect(AgentHooks.codex.isInstalled(in: file))

    let removed = try await run(
      ["remove-agent-hooks", "--agent", "codex"], environment: ["HOME": home.path])
    #expect(removed.succeeded, "\(removed.standardError)")
    #expect(!AgentHooks.codex.isInstalled(in: file))
  }
}
