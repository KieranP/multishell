import AppKit
import MultishellCore
import Testing

@testable import Multishell

/// Records what a host tells its delegate.
@MainActor
private final class HostRecorder: TerminalHostDelegate {
  var exits: [(TerminalSession.ID, Int32)] = []
  var titles: [String] = []
  var activity = 0
  func terminalHost(_ host: any TerminalHost, didRetitle id: TerminalSession.ID, to title: String) {
    titles.append(title)
  }
  func terminalHost(_ host: any TerminalHost, didExit id: TerminalSession.ID, code: Int32) {
    exits.append((id, code))
  }
  func terminalHost(_ host: any TerminalHost, didSeeActivityIn id: TerminalSession.ID) {
    activity += 1
  }
  func terminalHost(_ host: any TerminalHost, didFocus id: TerminalSession.ID) {}
}

/// SwiftTerm is the one engine that runs without a window or a GPU, so it is
/// the one whose wiring to the core can be exercised with a real child:
/// spawn, title through OSC, exit with a code, close.
@Suite(.serialized) @MainActor
struct SwiftTermHostTests {
  private let directory = URL(fileURLWithPath: NSTemporaryDirectory())

  private func waitUntil(_ condition: () -> Bool, seconds: Double = 8) async throws {
    for _ in 0..<Int(seconds * 20) where !condition() {
      try await Task.sleep(for: .milliseconds(50))
    }
  }

  @Test func aCommandsTitleAndExitCodeReachTheDelegateAndCloseIsSafeAfterwards() async throws {
    let host = SwiftTermTerminalHost()
    let recorder = HostRecorder()
    host.delegate = recorder
    let session = TerminalSession(
      worktreeID: "/w", workingDirectory: directory, title: "t",
      command: ["/bin/sh", "-c", "printf '\\033]0;from-the-shell\\007'; exit 3"])

    try host.open(session)
    #expect(host.openSessionIDs == [session.id])
    #expect(host.view(for: session.id) != nil)

    try await waitUntil { !recorder.exits.isEmpty }

    #expect(recorder.exits.map(\.0) == [session.id])
    #expect(recorder.exits.first?.1 == 3, "the code the child exited with")
    #expect(
      recorder.titles.contains("from-the-shell"), "OSC 0 reached the core: \(recorder.titles)")

    // The registry answers an exit with close. SwiftTerm still holds the
    // reaped pid, so close must not signal it; nothing to observe but the
    // absence of a crash and an empty host.
    host.close(session.id)
    #expect(host.openSessionIDs.isEmpty)
    #expect(host.view(for: session.id) == nil)
  }

  @Test func closingALiveSessionEndsItsChild() async throws {
    let host = SwiftTermTerminalHost()
    let recorder = HostRecorder()
    host.delegate = recorder
    let marker = directory.appendingPathComponent("multishell-alive-\(UUID().uuidString)")
    // The child announces itself, then waits to be killed; a trap would let
    // a plain TERM leave the marker behind.
    let session = TerminalSession(
      worktreeID: "/w", workingDirectory: directory, title: "t",
      command: [
        "/bin/sh", "-c",
        "echo $$ > '\(marker.path)'; trap 'rm -f \"\(marker.path)\"; exit 0' TERM; while :; do sleep 0.1; done",
      ])
    try host.open(session)
    try await waitUntil { FileManager.default.fileExists(atPath: marker.path) }
    let pid = try #require(
      Int32(
        try String(contentsOf: marker, encoding: .utf8).trimmingCharacters(
          in: .whitespacesAndNewlines)))

    host.close(session.id)

    try await waitUntil { !FileManager.default.fileExists(atPath: marker.path) }
    #expect(!FileManager.default.fileExists(atPath: marker.path), "SIGTERM never reached the shell")
    // Dead is not enough: an unreaped child stays in the table as a zombie.
    try await waitUntil { kill(pid, 0) != 0 }
    let state = try await ProcessState.of(pid)
    #expect(state == "gone", "the shell is still in the process table after close: \(state)")
    #expect(recorder.exits.isEmpty, "a close the app asked for is not reported as an exit")
    try? FileManager.default.removeItem(at: marker)
  }

  @Test func aShellThatIgnoresSIGTERMIsKilledAfterTheGraceAndReaped() async throws {
    let host = SwiftTermTerminalHost()
    host.terminationGrace = .milliseconds(300)
    let marker = directory.appendingPathComponent("multishell-stubborn-\(UUID().uuidString)")
    let session = TerminalSession(
      worktreeID: "/w", workingDirectory: directory, title: "t",
      command: [
        "/bin/sh", "-c", "trap '' TERM; echo $$ > '\(marker.path)'; while :; do sleep 0.1; done",
      ])
    try host.open(session)
    try await waitUntil { FileManager.default.fileExists(atPath: marker.path) }
    let pid = try #require(
      Int32(
        try String(contentsOf: marker, encoding: .utf8).trimmingCharacters(
          in: .whitespacesAndNewlines)))
    defer { try? FileManager.default.removeItem(at: marker) }

    host.close(session.id)

    try await waitUntil { kill(pid, 0) != 0 }
    #expect(try await ProcessState.of(pid) == "gone")
  }

  @Test func theShellSeesItsSessionIdentityInTheEnvironment() async throws {
    let host = SwiftTermTerminalHost()
    let recorder = HostRecorder()
    host.delegate = recorder
    let marker = directory.appendingPathComponent("multishell-env-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: marker) }
    let session = TerminalSession(
      worktreeID: "/w", workingDirectory: directory, title: "t",
      command: [
        "/bin/sh", "-c",
        "printf '%s|%s|%s|%s' \"$MULTISHELL_SESSION\" \"$MULTISHELL_WORKTREE\" \"$MULTISHELL_SOCKET\" \"$HOME\" > '\(marker.path)'",
      ])
    try host.open(session)
    try await waitUntil { !recorder.exits.isEmpty }

    let fields = try String(contentsOf: marker, encoding: .utf8).split(
      separator: "|", omittingEmptySubsequences: false)
    #expect(fields.count == 4)
    #expect(fields[0] == session.id.uuidString)
    #expect(fields[1] == session.workingDirectory.path)
    #expect(fields[2] == Paths.socketFile.path)
    #expect(!fields[3].isEmpty, "SwiftTerm's own defaults are kept alongside")
    host.close(session.id)
  }

  @Test func rawWaitStatusesAreReducedToExitCodesAndRealCodesPassThrough() {
    #expect(SwiftTermTerminalHost.exitStatus(768) == 3)
    #expect(SwiftTermTerminalHost.exitStatus(0) == 0)
    #expect(SwiftTermTerminalHost.exitStatus(3) == 3)
    #expect(SwiftTermTerminalHost.exitStatus(255) == 255)
    #expect(SwiftTermTerminalHost.exitStatus(256) == 1)
    #expect(SwiftTermTerminalHost.exitStatus(nil) == 0)
  }
}

/// `ps` state letter for a pid, or "gone".
private enum ProcessState {
  static func of(_ pid: Int32) async throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/ps")
    process.arguments = ["-o", "stat=", "-p", "\(pid)"]
    let pipe = Pipe()
    process.standardOutput = pipe
    try process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    return text.isEmpty ? "gone" : text
  }
}
