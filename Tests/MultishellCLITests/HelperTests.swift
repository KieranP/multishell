import Foundation
import TestScratch
import Testing

@testable import MultishellCore
@testable import MultishellProcess

/// The built `multishell` binary against a real socket: what a hook does,
/// end to end, minus Claude itself.
@Suite(.serialized)
struct HelperTests {
  @Test func stateReachesTheServerWithTheSessionFromTheEnvironment() async throws {
    let listener = try ReportListener()
    defer { listener.stop() }
    let path = listener.path
    let recorder = listener.recorder
    let session = UUID()

    let output = try await HelperBinary.run(
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

  @Test func everyOptionTheIntegrationsPassReachesTheReport() async throws {
    let listener = try ReportListener()
    defer { listener.stop() }
    let recorder = listener.recorder
    let session = UUID()

    let output = try await HelperBinary.run(
      [
        "state", "error", "--session", session.uuidString, "--cwd", "/w/repo", "--pid", "4242",
        "--message", "build failed", "--agent", "opencode", "--shell", "true", "--new-turn",
        "true",
      ],
      environment: ["MULTISHELL_SOCKET": listener.path.path])

    #expect(output.succeeded, "\(output.standardError)")
    try await waitUntil { !recorder.received.isEmpty }
    let report = SessionStateReport.parse(recorder.received.first ?? "")
    #expect(report?.state == .failed)
    #expect(report?.sessionID == session)
    #expect(report?.cwd == "/w/repo")
    #expect(report?.pid == 4242)
    #expect(report?.message == "build failed")
    #expect(report?.agent == "opencode")
    #expect(report?.isFromShellIntegration == true)
    #expect(report?.startsTurn == true)
  }

  @Test func stateCanSayTheAgentResumesAndThatAnEndWakesNoTurn() async throws {
    let listener = try ReportListener()
    defer { listener.stop() }
    let recorder = listener.recorder
    let environment = ["MULTISHELL_SOCKET": listener.path.path]

    let stop = try await HelperBinary.run(
      ["state", "done", "--agent", "opencode", "--resumes", "true"], environment: environment)
    #expect(stop.succeeded, "\(stop.standardError)")
    let end = try await HelperBinary.run(
      [
        "state", "running", "--agent", "opencode", "--subagent", "ses_1", "--subagent-phase",
        "ended", "--subagent-wakes", "false",
      ], environment: environment)
    #expect(end.succeeded, "\(end.standardError)")
    let orphan = try await HelperBinary.run(
      ["state", "running", "--subagent-wakes", "false"], environment: environment)
    #expect(orphan.status == 2)
    #expect(orphan.standardError.contains("--subagent-wakes"))

    try await waitUntil { recorder.received.count == 2 }
    let reports = recorder.received.map(SessionStateReport.parse)
    #expect(reports[0]?.resumesAfterWorkers == true)
    #expect(reports[1]?.subagent == SubagentReport(id: "ses_1", phase: .ended, wakesAgent: false))
  }

  @Test func stateCanListWhatIsStillOutIncludingNothing() async throws {
    let listener = try ReportListener()
    defer { listener.stop() }
    let recorder = listener.recorder
    let environment = ["MULTISHELL_SOCKET": listener.path.path]

    for out in ["ses_1,ses_2", ""] {
      let stop = try await HelperBinary.run(
        ["state", "done", "--agent", "opencode", "--out", out], environment: environment)
      #expect(stop.succeeded, "\(stop.standardError)")
    }

    try await waitUntil { recorder.received.count == 2 }
    let reports = recorder.received.map(SessionStateReport.parse)
    #expect(reports[0]?.workersOut?.map(\.id) == ["ses_1", "ses_2"])
    #expect(reports[1]?.workersOut == [], "nothing out is said, not left unsaid")
  }

  /// Any tool can say which agent is at the prompt, the way Claude's hooks
  /// do, so the app writes a dropped file the way that agent reads one.
  @Test func stateCanNameTheAgentAtThePrompt() async throws {
    let listener = try ReportListener()
    defer { listener.stop() }
    let path = listener.path
    let recorder = listener.recorder

    let output = try await HelperBinary.run(
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

    let output = try await HelperBinary.run(
      [
        "state", "running", "--agent", "opencode", "--subagent", "ses_1", "--subagent-phase",
        "working", "--subagent-type", "explore",
      ], environment: ["MULTISHELL_SOCKET": path.path])
    #expect(output.succeeded, "\(output.standardError)")
    try await waitUntil { !recorder.received.isEmpty }
    let report = SessionStateReport.parse(recorder.received.first ?? "")
    #expect(report?.subagent == SubagentReport(id: "ses_1", type: "explore", phase: .working))

    let prompt = try await HelperBinary.run(
      ["state", "running", "--agent", "opencode", "--new-turn", "true"],
      environment: ["MULTISHELL_SOCKET": path.path])
    #expect(prompt.succeeded, "\(prompt.standardError)")
    try await waitUntil { recorder.received.count == 2 }
    #expect(SessionStateReport.parse(recorder.received.last ?? "")?.startsTurn == true)

    let halfSaid = try await HelperBinary.run(
      ["state", "running", "--subagent", "ses_1"], environment: ["MULTISHELL_SOCKET": path.path])
    #expect(halfSaid.status == 2)
    #expect(halfSaid.standardError.contains("--subagent-phase"))
    let phaseAlone = try await HelperBinary.run(
      ["state", "running", "--subagent-phase", "ended"],
      environment: ["MULTISHELL_SOCKET": path.path])
    #expect(phaseAlone.status == 2)
    let typeAlone = try await HelperBinary.run(
      ["state", "running", "--subagent-type", "explore"],
      environment: ["MULTISHELL_SOCKET": path.path])
    #expect(typeAlone.status == 2)
    #expect(typeAlone.standardError.contains("--subagent"))

    // A report the server has read is the barrier: anything the three usage
    // errors had sent would be on the line before it.
    let after = try await HelperBinary.run(
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

    let inner = "\(PosixShellQuoting.quote(try HelperBinary.require().path)) state running"
    let output = try await HelperBinary.run(
      ["-c", "/bin/sh -c \(PosixShellQuoting.quote(inner))"],
      environment: ["MULTISHELL_SOCKET": path.path], executable: URL(fileURLWithPath: "/bin/sh"))
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
    let inner = "\(PosixShellQuoting.quote(try HelperBinary.require().path)) state running"
    let output = try await HelperBinary.run(
      ["-c", "echo $$; /bin/sh -c \(PosixShellQuoting.quote(inner))"],
      environment: ["MULTISHELL_SOCKET": path.path, "MULTISHELL_APP_PID": String(me)],
      executable: URL(fileURLWithPath: "/bin/sh"))
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

    #expect(
      try await HelperBinary.run(["command-started", "--pid", "4242"], environment: env).succeeded)
    #expect(
      try await HelperBinary.run(
        ["command-finished", "--exit", "0", "--duration", "3.5"], environment: env
      )
      .succeeded)
    #expect(
      try await HelperBinary.run(["command-finished", "--exit", "2"], environment: env).succeeded)
    #expect(
      try await HelperBinary.run(["command-finished", "--exit", "130"], environment: env).succeeded)

    try await waitUntil { recorder.received.count == 4 }
    let states = recorder.received.compactMap { SessionStateReport.parse($0)?.state }
    #expect(states == [.running, .done, .failed, .done], "signals are not failures")
    #expect(SessionStateReport.parse(recorder.received[1])?.duration == 3.5)
    #expect(SessionStateReport.parse(recorder.received[2])?.duration == nil)
    #expect(SessionStateReport.parse(recorder.received[0])?.sessionID == session)
    #expect(SessionStateReport.parse(recorder.received[0])?.cwd == "/w/repo")
    #expect(
      SessionStateReport.parse(recorder.received[0])?.pid == 4242,
      "the shell's pid, so a shell that exits mid-command clears its Working")
    #expect(
      recorder.received.allSatisfy { SessionStateReport.parse($0)?.isFromShellIntegration == true },
      "both are the shell's own, which is what may take an agent's mark back")

    #expect(try await HelperBinary.run(["state", "running"], environment: env).succeeded)
    try await waitUntil { recorder.received.count == 5 }
    #expect(
      SessionStateReport.parse(recorder.received[4])?.isFromShellIntegration == nil,
      "and a script of the user's is not, whatever state it reports")
  }

  @Test func stateWithNobodyListeningFailsLoudly() async throws {
    let output = try await HelperBinary.run(
      ["state", "done"], environment: ["MULTISHELL_SOCKET": "/tmp/ms-nobody.sock"])
    #expect(output.status == 1)
    #expect(output.standardError.contains("could not reach Multishell"))
  }

  @Test func usageErrorsExitTwo() async throws {
    #expect(try await HelperBinary.run([]).status == 2)
    #expect(try await HelperBinary.run(["state", "sleeping"]).status == 2)
    #expect(try await HelperBinary.run(["state", "done", "--bogus"]).status == 2)
    #expect(try await HelperBinary.run(["frobnicate"]).status == 2)
    let version = try await HelperBinary.run(["--version"])
    #expect(version.succeeded && version.standardOutput.contains("protocol version 1"))
  }

  @Test func aMisspeltOptionWithAValueIsAUsageErrorForEveryReportingCommand() async throws {
    let environment = ["MULTISHELL_SOCKET": "/tmp/ms-nobody.sock"]
    let lines = [
      ["state", "running", "--sesion", UUID().uuidString],
      ["command-started", "--pdi", "4242"],
      ["command-finished", "--exit", "0", "--duraton", "3"],
      ["relay", "--pdi", "4242"],
    ]
    for line in lines {
      let output = try await HelperBinary.run(line, environment: environment)
      #expect(output.status == 2, "\(line)")
      #expect(output.standardError.contains("unexpected argument --"), "\(line)")
    }
  }

}
