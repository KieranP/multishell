import Foundation
import TestScratch
import Testing

@testable import MultishellCore
@testable import MultishellProcess

/// The pid a report carries, walked up from the built binary through real
/// shells.
@Suite(.serialized)
struct HelperSessionEnvironmentTests {
  /// The pid reported is the program that ran the hook, past any shells
  /// between: here the test process, two `sh -c` layers up.
  @Test func thePidReportedIsTheFirstNonShellAncestor() async throws {
    let listener = try ReportListener()
    defer { listener.stop() }
    let path = listener.path
    let recorder = listener.recorder

    let inner = "\(AnyShellQuoting.quote(try HelperBinary.require().path)) state running"
    let output = try await HelperBinary.run(
      ["-c", "/bin/sh -c \(AnyShellQuoting.quote(inner))"],
      environment: ["MULTISHELL_SOCKET": path.path], standIn: URL(fileURLWithPath: "/bin/sh"))
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
    let inner = "\(AnyShellQuoting.quote(try HelperBinary.require().path)) state running"
    let output = try await HelperBinary.run(
      ["-c", "echo $$; /bin/sh -c \(AnyShellQuoting.quote(inner))"],
      environment: ["MULTISHELL_SOCKET": path.path, "MULTISHELL_APP_PID": String(me)],
      standIn: URL(fileURLWithPath: "/bin/sh"))
    #expect(output.succeeded, "\(output.standardError)")
    let outer = Int32(output.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines))

    try await waitUntil { !recorder.received.isEmpty }
    let report = SessionStateReport.parse(recorder.received.first ?? "")
    #expect(report?.pid == outer, "the shell nearest the app")
    #expect(report?.pid != me)
  }
}
