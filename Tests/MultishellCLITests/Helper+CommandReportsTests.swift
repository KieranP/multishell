import Foundation
import TestScratch
import Testing

@testable import MultishellCore
@testable import MultishellProcess

/// The shell's `command-started` and `command-finished`, run as the built
/// binary against a real socket.
@Suite(.serialized)
struct HelperCommandReportsTests {
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
        .succeeded
    )
    #expect(
      try await HelperBinary.run(
        ["command-finished", "--exit", "0", "--duration", "3.5"],
        environment: environment,
      )
      .succeeded
    )
    #expect(
      try await HelperBinary.run(["command-finished", "--exit", "2"], environment: environment)
        .succeeded
    )
    #expect(
      try await HelperBinary.run(["command-finished", "--exit", "130"], environment: environment)
        .succeeded
    )

    try await waitUntil { recorder.received.count == 4 }
    let states = recorder.received.compactMap { SessionStateReport.parse($0)?.state }
    #expect(states == [.running, .done, .failed, .done], "signals are not failures")
    #expect(SessionStateReport.parse(recorder.received[1])?.duration == 3.5)
    #expect(SessionStateReport.parse(recorder.received[2])?.duration == nil)
    #expect(SessionStateReport.parse(recorder.received[0])?.sessionID == session)
    #expect(SessionStateReport.parse(recorder.received[0])?.workingDirectory == "/w/repo")
    #expect(
      SessionStateReport.parse(recorder.received[0])?.pid == 4242,
      "the shell's pid, so a shell that exits mid-command clears its Working",
    )
    #expect(
      recorder.received.allSatisfy { SessionStateReport.parse($0)?.isFromShellIntegration == true },
      "both are the shell's own, which is what may take an agent's mark back",
    )

    #expect(try await HelperBinary.run(["state", "running"], environment: environment).succeeded)
    try await waitUntil { recorder.received.count == 5 }
    #expect(
      SessionStateReport.parse(recorder.received[4])?.isFromShellIntegration == nil,
      "and a script of the user's is not, whatever state it reports",
    )
  }
}
