import Foundation
import TestScratch
import Testing

@testable import MultishellCore
@testable import MultishellProcess

/// `state` and the shell's `command-started` and `command-finished`, run as
/// the built binary against a real socket.
@Suite(.serialized)
struct HelperStateReportsTests {
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
    #expect(report?.workingDirectory == "/w/repo")
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
    #expect(report?.workingDirectory == "/w/repo")
    #expect(report?.pid == 4242)
    #expect(report?.message == "build failed")
    #expect(report?.agentID == "opencode")
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
    #expect(reports[1]?.worker == WorkerReport(id: "ses_1", phase: .ended, wakesAgent: false))
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

  /// OpenCode's plugin has no payload to hand over and names a worker by flags.
  /// A phase without a worker, or a worker without a phase, is a usage error.
  @Test func stateNamesAWorkerOnlyWithItsIdAndPhaseTogether() async throws {
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
    #expect(report?.worker == WorkerReport(id: "ses_1", type: "explore", phase: .working))

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

    #expect(
      try await listener.linesUpToABarrier().count == 2, "no half-said worker reached the app")
  }

  @Test func commandStartedAndFinishedMapToRunningDoneAndFailed() async throws {
    let listener = try ReportListener()
    defer { listener.stop() }
    let path = listener.path
    let recorder = listener.recorder
    let session = UUID()
    let environment = [
      "MULTISHELL_SOCKET": path.path, "MULTISHELL_SESSION": session.uuidString,
      "MULTISHELL_WORKTREE": "/w/repo",
    ]

    #expect(
      try await HelperBinary.run(["command-started", "--pid", "4242"], environment: environment)
        .succeeded)
    #expect(
      try await HelperBinary.run(
        ["command-finished", "--exit", "0", "--duration", "3.5"], environment: environment
      )
      .succeeded)
    #expect(
      try await HelperBinary.run(["command-finished", "--exit", "2"], environment: environment)
        .succeeded)
    #expect(
      try await HelperBinary.run(["command-finished", "--exit", "130"], environment: environment)
        .succeeded)

    try await waitUntil { recorder.received.count == 4 }
    let states = recorder.received.compactMap { SessionStateReport.parse($0)?.state }
    #expect(states == [.running, .done, .failed, .done], "signals are not failures")
    #expect(SessionStateReport.parse(recorder.received[1])?.duration == 3.5)
    #expect(SessionStateReport.parse(recorder.received[2])?.duration == nil)
    #expect(SessionStateReport.parse(recorder.received[0])?.sessionID == session)
    #expect(SessionStateReport.parse(recorder.received[0])?.workingDirectory == "/w/repo")
    #expect(
      SessionStateReport.parse(recorder.received[0])?.pid == 4242,
      "the shell's pid, so a shell that exits mid-command clears its Working")
    #expect(
      recorder.received.allSatisfy { SessionStateReport.parse($0)?.isFromShellIntegration == true },
      "both are the shell's own, which is what may take an agent's mark back")

    #expect(try await HelperBinary.run(["state", "running"], environment: environment).succeeded)
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
}
