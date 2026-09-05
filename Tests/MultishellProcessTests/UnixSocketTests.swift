import Foundation
import Testing

@testable import MultishellProcess

/// A server on a temp path with a recorder for the lines it receives.
private final class LineRecorder: @unchecked Sendable {
  private let lock = NSLock()
  private var lines: [String] = []
  func record(_ line: String) { lock.withLock { lines.append(line) } }
  var received: [String] { lock.withLock { lines } }
}

private func socketPath() -> URL {
  // `$TMPDIR` on macOS is long; `sun_path` allows 104 bytes.
  URL(fileURLWithPath: "/tmp/ms-\(UUID().uuidString.prefix(8)).sock")
}

private func waitUntil(_ condition: @escaping () -> Bool, seconds: Double = 8) async throws {
  for _ in 0..<Int(seconds * 20) where !condition() {
    try await Task.sleep(for: .milliseconds(50))
  }
}

@Suite(.serialized)
struct UnixSocketServerTests {
  @Test func linesFromSeveralClientsArriveWholeAndTheFileIsPrivate() async throws {
    let path = socketPath()
    let server = UnixSocketServer(path: path)
    defer { server.stop() }
    let recorder = LineRecorder()
    server.onLine = { recorder.record($0) }
    try server.start()

    let mode = try FileManager.default.attributesOfItem(atPath: path.path)[.posixPermissions]
    #expect((mode as? Int) == 0o600, "mode \(String(describing: mode))")

    try UnixSocketClient.send("one\ntwo\n", to: path)
    try UnixSocketClient.send("three without newline", to: path)
    // A line split across two writes on one connection.
    try UnixSocketClient.send("four\nfive", to: path)

    try await waitUntil { recorder.received.count == 5 }
    #expect(recorder.received.sorted() == ["five", "four", "one", "three without newline", "two"])
  }

  @Test func aStaleSocketFileIsReplacedButALiveOneIsNot() throws {
    let path = socketPath()
    let first = UnixSocketServer(path: path)
    try first.start()

    let second = UnixSocketServer(path: path)
    #expect(throws: SocketFailure.self) { try second.start() }
    do {
      try second.start()
    } catch let failure as SocketFailure {
      #expect(failure.kind == .inUse)
    }
    #expect(FileManager.default.fileExists(atPath: path.path), "the live socket was not unlinked")

    // The first instance goes away without cleaning up, as a crash would.
    first.abandonForTesting()
    #expect(FileManager.default.fileExists(atPath: path.path))
    try second.start()
    second.stop()
    #expect(!FileManager.default.fileExists(atPath: path.path), "stop unlinks")
  }

  @Test func aPathTooLongForTheAddressIsRefusedUpFront() {
    let long = URL(fileURLWithPath: "/tmp/" + String(repeating: "x", count: 120) + ".sock")
    let server = UnixSocketServer(path: long)
    do {
      try server.start()
      Issue.record("bound a path that cannot fit sun_path")
    } catch let failure as SocketFailure {
      #expect(failure.kind == .pathTooLong)
    } catch {
      Issue.record("wrong error: \(error)")
    }
  }

  @Test func aClientWithNobodyListeningGetsAnErrorNotAHang() {
    let path = socketPath()
    do {
      try UnixSocketClient.send("hello\n", to: path)
      Issue.record("sent to nobody")
    } catch let failure as SocketFailure {
      if case .system(let operation, _) = failure.kind {
        #expect(operation == "connect")
      } else {
        Issue.record("wrong kind: \(failure.kind)")
      }
    } catch {
      Issue.record("wrong error: \(error)")
    }
  }

  @Test func aClientThatNeverSendsANewlineIsDroppedAtTheCap() async throws {
    let path = socketPath()
    let server = UnixSocketServer(path: path)
    defer { server.stop() }
    let recorder = LineRecorder()
    server.onLine = { recorder.record($0) }
    try server.start()

    let flood = String(repeating: "a", count: UnixSocketServer.maximumLineLength + 10)
    try? UnixSocketClient.send(flood, to: path)
    try UnixSocketClient.send("after\n", to: path)

    try await waitUntil { recorder.received.contains("after") }
    #expect(recorder.received == ["after"], "the flood produced no line")
  }
}

extension UnixSocketServer {
  /// Leaves the socket file behind with nothing listening, the way a
  /// crashed instance does. Closing the descriptors without unlinking.
  fileprivate func abandonForTesting() {
    let path = Mirror(reflecting: self).children.first { $0.label == "path" }!.value as! String
    stop()
    // `stop` unlinked it; put a dead socket file back.
    let descriptor = socket(AF_UNIX, UnixSocketAddress.streamType, 0)
    try? UnixSocketAddress.bindSocket(descriptor, to: path)
    close(descriptor)
  }
}
