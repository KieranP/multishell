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

  /// Why a refused connect is not proof that nobody is there: a live
  /// instance whose accept backlog is full refuses one exactly as a dead
  /// instance's socket file does, and the second launch used to read that as
  /// nobody being behind it.
  @Test func aLiveServerWhoseBacklogIsFullRefusesConnectsLikeADeadOne() throws {
    let path = socketPath()
    let blocked = DispatchQueue(label: "ms-test-blocked")
    let server = UnixSocketServer(path: path, queue: blocked)
    defer { server.stop() }
    try server.start()

    // Up but unable to accept: its queue is busy, as a wedged main thread
    // would be. The backlog fills and the next connect is refused.
    let release = DispatchSemaphore(value: 0)
    blocked.async { release.wait() }
    defer { release.signal() }
    var pending: [Int32] = []
    defer { for descriptor in pending { close(descriptor) } }
    var refused = false
    while pending.count < 64, !refused {
      let descriptor = try UnixSocketAddress.newSocket(path: path.path)
      do {
        try UnixSocketAddress.connectSocket(descriptor, to: path.path)
        pending.append(descriptor)
      } catch {
        close(descriptor)
        refused = true
      }
    }
    #expect(refused, "the backlog never filled, so nothing is being tested")
  }

  /// So the claim decides instead. Held by another process for as long as it
  /// listens: a socket file beside a held claim has a live owner, whatever
  /// the connect said, and taking it would leave that instance deaf for good.
  @Test func aSocketWhoseClaimAnotherProcessHoldsIsNotTakenOver() throws {
    guard FileManager.default.isExecutableFile(atPath: "/usr/bin/python3") else { return }
    let path = socketPath()
    let server = UnixSocketServer(path: path)
    defer { server.stop() }
    // A socket file with nothing listening: what a crashed instance leaves,
    // and what a live one with a full backlog is indistinguishable from.
    let dead = socket(AF_UNIX, UnixSocketAddress.streamType, 0)
    try UnixSocketAddress.bindSocket(dead, to: path.path)
    close(dead)

    let holder = Process()
    holder.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
    holder.arguments = [
      "-c",
      """
      import fcntl, sys, time
      handle = open(sys.argv[1], 'w')
      fcntl.lockf(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
      print('held', flush=True)
      time.sleep(60)
      """, server.claimPath,
    ]
    let output = Pipe()
    holder.standardOutput = output
    try holder.run()
    defer { holder.terminate() }
    let announced = String(
      decoding: output.fileHandleForReading.readData(ofLength: 5), as: UTF8.self)
    #expect(announced.hasPrefix("held"), "the holder did not take the claim: \(announced)")

    do {
      try server.start()
      Issue.record("took a socket whose owner is alive")
    } catch let failure as SocketFailure {
      #expect(failure.kind == .inUse)
    }
    #expect(FileManager.default.fileExists(atPath: path.path), "and left it where it was")
  }

  /// Under a permissive umask the socket still ends up private. The window
  /// between bind and chmod is what the umask around the bind closes, and
  /// that window is not observable from here.
  @Test func theSocketIsPrivateWhateverTheUmask() throws {
    let path = socketPath()
    let previous = umask(0)
    defer { umask(previous) }
    let server = UnixSocketServer(path: path)
    defer { server.stop() }
    try server.start()

    let mode = try FileManager.default.attributesOfItem(atPath: path.path)[.posixPermissions]
    #expect(mode as? Int == 0o600)
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

  /// A start that fails after taking the claim has to let it go: `flock`
  /// refuses a second description of a file even to the process holding it,
  /// so a retry would otherwise read its own lock as another instance.
  @Test func aFailedStartLetsItsClaimGoSoARetrySaysWhatIsWrong() {
    let long = URL(fileURLWithPath: "/tmp/" + String(repeating: "y", count: 120) + ".sock")
    // Two instances, both kept: what the second must not meet is the first's
    // abandoned lock, read as another copy of the app.
    let servers = [UnixSocketServer(path: long), UnixSocketServer(path: long)]
    defer { for server in servers { server.stop() } }
    for (attempt, server) in servers.enumerated() {
      do {
        try server.start()
        Issue.record("bound a path that cannot fit sun_path")
      } catch let failure as SocketFailure {
        #expect(failure.kind == .pathTooLong, "attempt \(attempt)")
      } catch {
        Issue.record("wrong error: \(error)")
      }
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

@Suite
struct AcceptOutcomeTests {
  /// The read source on a listening socket is level-triggered, so a pending
  /// connection nothing accepts fires the handler again at once.
  @Test func onlyRunningOutOfNothingEndsTheAcceptLoop() {
    #expect(UnixSocketServer.AcceptOutcome(errno: EAGAIN) == .drained)
    #expect(UnixSocketServer.AcceptOutcome(errno: EWOULDBLOCK) == .drained)
    #expect(UnixSocketServer.AcceptOutcome(errno: EINTR) == .again, "a signal is not an answer")
    #expect(
      UnixSocketServer.AcceptOutcome(errno: ECONNABORTED) == .again,
      "the peer went; the next one is still waiting")
    #expect(
      UnixSocketServer.AcceptOutcome(errno: EMFILE) == .outOfDescriptors,
      "returning here spins the queue against a backlog that never clears")
    #expect(UnixSocketServer.AcceptOutcome(errno: ENFILE) == .outOfDescriptors)
    #expect(UnixSocketServer.AcceptOutcome(errno: EINVAL) == .drained, "unknown: stop, do not spin")
  }
}
