import Foundation
import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellProcess

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

      """,
      to: path,
    )

    try await waitUntil { !received.isEmpty }
    #expect(received.count == 1)
    #expect(received.first?.sessionID == session)
    #expect(received.first?.state == .attention)
    #expect(received.first?.pid == 41)
    #expect(received.first?.message == "Needs Bash")
  }

  @Test func aRequestIsAnsweredOnItsConnectionAndAReportOrUnknownRequestIsNot() async throws {
    let path = Scratch.socketPath("src")
    let source = SocketStateSource(path: path)
    defer {
      source.stop()
      Scratch.removeSocket(path)
    }
    var asked: [ControlRequest] = []
    source.onRequest = { request in
      asked.append(request)
      return .output("listed")
    }
    try source.start()
    let ask = { (line: String) in
      try await Task.detached {
        try UnixSocketClient.request(line, to: path, timeout: .seconds(10))
      }
      .value
    }

    let answer = try await ask(try ControlRequest.listTabs(worktree: nil).encodedLine())
    let report = try await ask(#"{"v":1,"state":"done"}"# + "\n")
    let unknown = try await ask(#"{"v":1,"request":{"teleport":{}}}"# + "\n")

    #expect(ControlReply.parse(answer) == .output("listed"))
    #expect(report.isEmpty)
    #expect(unknown.isEmpty, "the helper words an empty answer as an older app")
    #expect(asked == [.listTabs(worktree: nil)])
  }

  @Test func aRequestWhoseHelperHangsUpHasItsAnswerCancelled() async throws {
    let path = Scratch.socketPath("src")
    let source = SocketStateSource(path: path)
    defer {
      source.stop()
      Scratch.removeSocket(path)
    }
    var isAsked = false
    var isCancelled = false
    source.onRequest = { _ in
      isAsked = true
      while !Task.isCancelled { try? await Task.sleep(for: .milliseconds(20)) }
      isCancelled = true
      return nil
    }
    try source.start()
    let helper = try UnixSocket.newSocket(reportingAs: path.path)
    try UnixSocket.connectSocket(helper, to: path.path)
    let line = try ControlRequest.listTabs(worktree: nil).encodedLine()
    try UnixSocket.write(Array(line.utf8), to: helper, until: nil)
    shutdown(helper, SHUT_WR)
    try await waitUntil { isAsked }
    try #require(isAsked)

    close(helper)
    try await waitUntil { isCancelled }

    #expect(isCancelled)
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
