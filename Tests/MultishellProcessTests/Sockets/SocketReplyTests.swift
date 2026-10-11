import Foundation
import TestScratch
import Testing

@testable import MultishellProcess

@Suite(.serialized)
struct SocketReplyTests {
  private func server(
    _ tag: String,
    onLine: @escaping @Sendable (String, SocketReplyChannel) -> Void,
  ) throws -> (server: UnixSocketServer, path: URL) {
    let path = Scratch.socketPath(tag)
    let server = UnixSocketServer(path: path)
    server.onLine = onLine
    try server.start()
    return (server, path)
  }

  @Test func anAnswerSentAfterTheClientsEOFStillReachesIt() throws {
    let (server, path) = try server("rep") { line, channel in
      let reply = channel.open()
      DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(200)) {
        reply?.send("answer to \(line)\n")
      }
    }
    defer {
      server.stop()
      Scratch.removeSocket(path)
    }

    let answer = try UnixSocketClient.request("ping\n", to: path, timeout: .seconds(10))

    #expect(answer == "answer to ping\n")
  }

  @Test func anAnswerLongerThanTheSocketBufferArrivesWhole() throws {
    let long = String(repeating: "x", count: 1_000_000) + "\n"
    let (server, path) = try server("rep") { _, channel in channel.open()?.send(long) }
    defer {
      server.stop()
      Scratch.removeSocket(path)
    }

    let answer = try UnixSocketClient.request("ping\n", to: path, timeout: .seconds(10))

    #expect(answer.count == long.count)
  }

  @Test func twoAnswersOnOneConnectionArriveEachWholeRatherThanInterleaved() throws {
    let (server, path) = try server("rep") { line, channel in
      channel.open()?.send(String(repeating: line, count: 1_000_000) + "\n")
    }
    defer {
      server.stop()
      Scratch.removeSocket(path)
    }

    for _ in 0..<5 {
      let answer = try slowlyRead("a\nb\n", from: path)

      let lines = answer.split(separator: "\n")
      #expect(lines.count == 2)
      #expect(Set(lines.map { Set($0) }) == [["a"], ["b"]])
    }
  }

  private func slowlyRead(_ text: String, from path: URL) throws -> String {
    let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
    defer { close(descriptor) }
    var address = sockaddr_un()
    address.sun_family = sa_family_t(AF_UNIX)
    withUnsafeMutableBytes(of: &address.sun_path) { raw in
      for (index, byte) in path.path.utf8.enumerated() { raw[index] = byte }
    }
    let connected = withUnsafePointer(to: &address) { pointer in
      pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
        connect(descriptor, socketAddress, socklen_t(MemoryLayout<sockaddr_un>.size))
      }
    }
    try #require(connected == 0)
    _ = Array(text.utf8).withUnsafeBufferPointer { write(descriptor, $0.baseAddress, $0.count) }
    shutdown(descriptor, SHUT_WR)
    var answer: [UInt8] = []
    var chunk = [UInt8](repeating: 0, count: 1024)
    while true {
      let count = read(descriptor, &chunk, chunk.count)
      guard count > 0 else { break }
      answer += chunk[0..<count]
      usleep(20)
    }
    return String(decoding: answer, as: UTF8.self)
  }

  @Test func aListenerThatNeverOpensAReplyGivesAnEmptyAnswer() throws {
    let (server, path) = try server("rep") { _, _ in }
    defer {
      server.stop()
      Scratch.removeSocket(path)
    }

    #expect(try UnixSocketClient.request("ping\n", to: path, timeout: .seconds(10)) == "")
  }

  @Test func aReplyDroppedUnsentClosesTheConnectionAsNoAnswer() throws {
    let (server, path) = try server("rep") { _, channel in _ = channel.open() }
    defer {
      server.stop()
      Scratch.removeSocket(path)
    }

    #expect(try UnixSocketClient.request("ping\n", to: path, timeout: .seconds(10)) == "")
  }

  @Test func aReplyHeldOpenRunsTheClientOutOfTimeRatherThanHangingIt() throws {
    let held = Recorder<SocketReply>()
    let (server, path) = try server("rep") { _, channel in
      if let reply = channel.open() { held.record(reply) }
    }
    defer {
      server.stop()
      Scratch.removeSocket(path)
    }

    let failure = #expect(throws: SocketNoAnswer.self) {
      try UnixSocketClient.request("ping\n", to: path, timeout: .seconds(1))
    }

    #expect(failure?.timeout == .seconds(1))
    #expect(held.received.count == 1)
  }

  @Test func aTimeoutUnderASecondStillRunsOut() throws {
    let held = Recorder<SocketReply>()
    let (server, path) = try server("rep") { _, channel in
      if let reply = channel.open() { held.record(reply) }
    }
    defer {
      server.stop()
      Scratch.removeSocket(path)
    }
    let outcome = Recorder<Bool>()
    let finished = DispatchSemaphore(value: 0)

    Thread.detachNewThread {
      let ranOut =
        (try? UnixSocketClient.request("ping\n", to: path, timeout: .milliseconds(300)))
        == nil
      outcome.record(ranOut)
      finished.signal()
    }

    #expect(finished.wait(timeout: .now() + 5) == .success)
    #expect(outcome.received == [true])
  }

  @Test func anAnswerReadSlowerThanTheTimeoutButNeverStalledArrivesWhole() throws {
    var pair: [Int32] = [0, 0]
    try #require(socketpair(AF_UNIX, SOCK_STREAM, 0, &pair) == 0)
    defer { close(pair[1]) }
    _ = fcntl(pair[0], F_SETFL, fcntl(pair[0], F_GETFL) | O_NONBLOCK)
    let long = String(repeating: "x", count: 2_000_000)
    let reply = SocketReply(descriptor: pair[0], stallTimeout: .seconds(1))
    let started = ContinuousClock.now

    reply.send(long)
    var received = 0
    var chunk = [UInt8](repeating: 0, count: 64 * 1024)
    while true {
      let count = Darwin.read(pair[1], &chunk, chunk.count)
      if count <= 0 { break }
      received += count
      Thread.sleep(forTimeInterval: 0.05)
    }

    try #require(started.duration(to: .now) > .seconds(1), "read for longer than the timeout")
    #expect(received == long.utf8.count)
  }

  @Test func aWatchedReplySaysItsClientHungUpButNotThatItFinishedWriting() throws {
    var pair: [Int32] = [0, 0]
    try #require(socketpair(AF_UNIX, SOCK_STREAM, 0, &pair) == 0)
    let reply = SocketReply(descriptor: pair[0])
    let hungUp = DispatchSemaphore(value: 0)
    reply.watchForHangUp { hungUp.signal() }

    shutdown(pair[1], SHUT_WR)
    #expect(hungUp.wait(timeout: .now() + .milliseconds(600)) == .timedOut)
    close(pair[1])

    #expect(hungUp.wait(timeout: .now() + 5) == .success)
  }

  @Test func aClientThatStopsReadingHoldsUpNoOtherAnswer() throws {
    let long = String(repeating: "x", count: 4_000_000) + "\n"
    let answered = Recorder<String>()
    let (server, path) = try server("rep") { line, channel in
      channel.open()?.send(line.hasPrefix("stuck") ? long : "quick\n")
      answered.record(line)
    }
    defer {
      server.stop()
      Scratch.removeSocket(path)
    }
    let stuck = try UnixSocket.newSocket(reportingAs: path.path)
    defer { close(stuck) }
    try UnixSocket.connectSocket(stuck, to: path.path)
    _ = "stuck\n".withCString { Darwin.write(stuck, $0, 6) }
    let deadline = ContinuousClock.now + .seconds(5)
    while answered.received.isEmpty, ContinuousClock.now < deadline {
      Thread.sleep(forTimeInterval: 0.01)
    }
    try #require(!answered.received.isEmpty, "the stuck answer is under way")
    let started = ContinuousClock.now

    let answer = try UnixSocketClient.request("ping\n", to: path, timeout: .seconds(10))

    #expect(answer == "quick\n")
    #expect(started.duration(to: .now) < .seconds(2))
  }
}
