import Foundation
import MultishellCore
import MultishellProcess
import Testing

@testable import MultishellAppCore

/// The channel the app listens on, driven with a real client. Reports land
/// on the main actor parsed; anything else on the line is dropped there.
@Suite(.serialized) @MainActor
struct SocketStateSourceTests {
  private func socketPath() -> URL {
    // `$TMPDIR` on macOS is long; `sun_path` allows 104 bytes.
    URL(fileURLWithPath: "/tmp/ms-src-\(UUID().uuidString.prefix(8)).sock")
  }

  private func waitUntil(_ condition: () -> Bool, seconds: Double = 8) async throws {
    for _ in 0..<Int(seconds * 20) where !condition() {
      try await Task.sleep(for: .milliseconds(50))
    }
  }

  @Test func aReportOnTheSocketReachesTheHandlerAndAStrayLineDoesNot() async throws {
    let path = socketPath()
    let source = SocketStateSource(path: path)
    defer { source.stop() }
    var received: [SessionStateReport] = []
    source.onReport = { received.append($0) }
    try source.start()

    let session = UUID()
    try UnixSocketClient.send(
      """
      not json at all
      {"v":1,"session":"\(session.uuidString)","state":"attention","pid":41,"message":"Needs Bash"}

      """, to: path)

    try await waitUntil { !received.isEmpty }
    #expect(received.count == 1)
    #expect(received.first?.sessionID == session)
    #expect(received.first?.state == .attention)
    #expect(received.first?.pid == 41)
    #expect(received.first?.message == "Needs Bash")
  }

  @Test func stopUnlinksTheSocketSoTheNextLaunchNeedNotProbeIt() throws {
    let path = socketPath()
    let source = SocketStateSource(path: path)
    try source.start()
    #expect(FileManager.default.fileExists(atPath: path.path))
    source.stop()
    #expect(!FileManager.default.fileExists(atPath: path.path))
  }
}
