import Foundation
import TestScratch
import Testing

@testable import MultishellProcess

@Suite(.serialized)
struct UnixSocketServerTests {
  @Test func linesFromSeveralClientsArriveWholeAndTheFileIsPrivate() async throws {
    let path = Scratch.socketPath("srv")
    let server = UnixSocketServer(path: path)
    defer {
      server.stop()
      Scratch.removeSocket(path)
    }
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
    let path = Scratch.socketPath("srv")
    defer { Scratch.removeSocket(path) }
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

  /// A live instance with a full accept backlog refuses a connect exactly as a dead one's
  /// socket file does, and the second launch used to read that as nobody there.
  @Test func aLiveServerWhoseBacklogIsFullRefusesConnectsLikeADeadOne() throws {
    let path = Scratch.socketPath("srv")
    let blocked = DispatchQueue(label: "ms-test-blocked")
    let server = UnixSocketServer(path: path, queue: blocked)
    defer {
      server.stop()
      Scratch.removeSocket(path)
    }
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
      let descriptor = try UnixSocket.newSocket(path: path.path)
      do {
        try UnixSocket.connectSocket(descriptor, to: path.path)
        pending.append(descriptor)
      } catch {
        close(descriptor)
        refused = true
      }
    }
    #expect(refused, "the backlog never filled, so nothing is being tested")
  }

  /// So the claim decides: a socket file beside a claim another process holds has a live
  /// owner, whatever the connect said, and taking it would leave that owner deaf for good.
  @Test func aSocketWhoseClaimAnotherProcessHoldsIsNotTakenOver() throws {
    guard FileManager.default.isExecutableFile(atPath: "/usr/bin/python3") else { return }
    let path = Scratch.socketPath("srv")
    let server = UnixSocketServer(path: path)
    defer {
      server.stop()
      Scratch.removeSocket(path)
    }
    // A socket file with nothing listening: what a crashed instance leaves,
    // and what a live one with a full backlog is indistinguishable from.
    let dead = socket(AF_UNIX, SOCK_STREAM, 0)
    try UnixSocket.bindSocket(dead, to: path.path)
    close(dead)
    // A server that never started unlinks nothing.
    defer { unlink(path.path) }

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

  /// The umask around the bind closes the window between bind and chmod, and that window is
  /// not observable from here.
  @Test func theSocketIsPrivateWhateverTheUmask() throws {
    let path = Scratch.socketPath("srv")
    let previous = umask(0)
    defer { umask(previous) }
    let server = UnixSocketServer(path: path)
    defer {
      server.stop()
      Scratch.removeSocket(path)
    }
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

  /// `flock` refuses a second description of a file even to the process holding it, so a
  /// retry would otherwise read its own lock as another instance.
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

  /// The probe finds this instance answering, and letting the claim go on that would leave
  /// the socket unguarded while the listener kept accepting.
  @Test func startingALiveServerAgainKeepsItsClaim() async throws {
    guard FileManager.default.isExecutableFile(atPath: "/usr/bin/python3") else { return }
    let path = Scratch.socketPath("srv")
    let server = UnixSocketServer(path: path)
    defer {
      server.stop()
      Scratch.removeSocket(path)
    }
    let recorder = LineRecorder()
    server.onLine = { recorder.record($0) }
    try server.start()
    try server.start()

    // Another process is the only honest reader: a process's own record
    // locks never conflict with each other, so `F_GETLK` here says unlocked.
    let taker = Process()
    taker.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
    taker.arguments = [
      "-c",
      """
      import fcntl, sys
      handle = open(sys.argv[1], 'w')
      try:
          fcntl.lockf(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
          print('took', flush=True)
      except OSError:
          print('refused', flush=True)
      """, server.claimPath,
    ]
    let output = Pipe()
    taker.standardOutput = output
    try taker.run()
    taker.waitUntilExit()
    let answer = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    #expect(answer.hasPrefix("refused"), "the claim was let go: \(answer)")

    try UnixSocketClient.send("still here\n", to: path)
    try await waitUntil { !recorder.received.isEmpty }
    #expect(recorder.received == ["still here"])
  }

  /// Bound at `path + ".b"` and renamed in, so the limit is two bytes short
  /// of `sun_path`, and the refusal names the socket, not the staging file.
  @Test func aPathThatFitsOnlyWithoutItsStagingSuffixIsRefusedByItsOwnName() {
    for count in [102, 103] {
      let long = URL(fileURLWithPath: "/tmp/" + String(repeating: "z", count: count - 10) + ".sock")
      #expect(long.path.utf8.count == count)
      let server = UnixSocketServer(path: long)
      defer {
        server.stop()
        Scratch.removeSocket(long)
      }
      do {
        try server.start()
        Issue.record("bound \(count) bytes, whose staging name cannot fit")
      } catch let failure as SocketFailure {
        #expect(failure.kind == .pathTooLong, "\(count)")
        #expect(failure.path == long.path, "\(count): named \(failure.path)")
      } catch {
        Issue.record("wrong error: \(error)")
      }
    }
  }

  @Test func aPathThatFitsWithItsStagingSuffixStarts() throws {
    let path = URL(fileURLWithPath: "/tmp/" + String(repeating: "w", count: 91) + ".sock")
    #expect(path.path.utf8.count == 101)
    let server = UnixSocketServer(path: path)
    defer {
      server.stop()
      Scratch.removeSocket(path)
    }
    try server.start()
    #expect(FileManager.default.fileExists(atPath: path.path))
  }

  @Test func aClientWithNobodyListeningGetsAnErrorNotAHang() {
    let path = Scratch.socketPath("srv")
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
    let path = Scratch.socketPath("srv")
    let server = UnixSocketServer(path: path)
    defer {
      server.stop()
      Scratch.removeSocket(path)
    }
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
    let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
    try? UnixSocket.bindSocket(descriptor, to: path)
    close(descriptor)
  }
}
