import Foundation
import MultishellCore
import MultishellProcess
import TestScratch
import Testing

@testable import MultishellAppCore

/// The channel the app listens on, driven with a real client. Reports land
/// on the main actor parsed; anything else on the line is dropped there.
@Suite(.serialized) @MainActor
struct SocketStateSourceTests {
  @Test func aReportOnTheSocketReachesTheHandlerAndAStrayLineDoesNot() async throws {
    let path = Scratch.socketPath("src")
    let source = SocketStateSource(path: path)
    defer {
      source.stop()
      Scratch.removeSocket(path)
    }
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
    let path = Scratch.socketPath("src")
    defer { Scratch.removeSocket(path) }
    let source = SocketStateSource(path: path)
    try source.start()
    #expect(FileManager.default.fileExists(atPath: path.path))
    source.stop()
    #expect(!FileManager.default.fileExists(atPath: path.path))
  }
}
