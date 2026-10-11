import Foundation
import TestScratch
import Testing

@testable import MultishellProcess

@Suite
struct UnixSocketClientTests {
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

  @Test func aRequestToAListenerThatNeverReadsRunsOutOfTimeWhileSending() throws {
    let (listener, path) = try listening()
    defer {
      close(listener)
      Scratch.removeSocket(path)
    }
    let request = String(repeating: "a", count: 60_000) + "\n"
    #expect(
      runsOutOfTime(within: 5) {
        _ = try UnixSocketClient.request(request, to: path, timeout: .milliseconds(300))
      }
    )
    let connection = accept(listener, nil, nil)
    defer { close(connection) }
    #expect(bytesUntilTheEnd(of: connection) < request.utf8.count, "it gave up mid-send")
  }

  @Test func aListenerThatHangsUpMidWriteIsAnErrorNotTheProcessKilled() throws {
    let (listener, path) = try listening()
    defer {
      close(listener)
      Scratch.removeSocket(path)
    }
    Thread.detachNewThread {
      let connection = accept(listener, nil, nil)
      if connection >= 0 { close(connection) }
    }

    #expect(throws: SocketFailure.self) {
      try UnixSocketClient.send(String(repeating: "a", count: 4_000_000), to: path)
    }
  }

  @Test func anAnswerThatTricklesInPastTheTimeoutRunsOutOfTime() throws {
    let (listener, path) = try listening()
    defer {
      close(listener)
      Scratch.removeSocket(path)
    }
    Thread.detachNewThread {
      let connection = accept(listener, nil, nil)
      guard connection >= 0 else { return }
      defer { close(connection) }
      var byte: UInt8 = 0
      while read(connection, &byte, 1) > 0, byte != UInt8(ascii: "\n") {}
      for _ in 0..<20 {
        var letter = UInt8(ascii: "a")
        guard Darwin.write(connection, &letter, 1) == 1 else { return }
        Thread.sleep(forTimeInterval: 0.1)
      }
    }
    #expect(
      runsOutOfTime(within: 10) {
        _ = try UnixSocketClient.request("ask\n", to: path, timeout: .milliseconds(400))
      }
    )
  }

  @Test func aRequestTheListenerReadsInTricklesRunsOutOfTimeWhileSending() throws {
    let (listener, path) = try listening()
    defer {
      close(listener)
      Scratch.removeSocket(path)
    }
    let received = Recorder<Int>()
    let drained = DispatchSemaphore(value: 0)
    Thread.detachNewThread {
      let connection = accept(listener, nil, nil)
      defer {
        close(connection)
        drained.signal()
      }
      var chunk = [UInt8](repeating: 0, count: 4_096)
      var total = 0
      for _ in 0..<100 {
        let count = read(connection, &chunk, chunk.count)
        guard count > 0 else { break }
        total += count
        Thread.sleep(forTimeInterval: 0.1)
      }
      received.record(total)
    }
    let request = String(repeating: "a", count: 200_000) + "\n"
    #expect(
      runsOutOfTime(within: 10) {
        _ = try UnixSocketClient.request(request, to: path, timeout: .milliseconds(400))
      }
    )
    #expect(drained.wait(timeout: .now() + 15) == .success)
    #expect((received.received.first ?? .max) < request.utf8.count, "it gave up mid-send")
  }

  @Test func aSendToAListenerThatNeverReadsRunsOutOfTime() throws {
    let (listener, path) = try listening()
    defer {
      close(listener)
      Scratch.removeSocket(path)
    }
    let report = String(repeating: "a", count: 200_000) + "\n"
    #expect(
      runsOutOfTime(within: 5) {
        try UnixSocketClient.send(report, to: path, timeout: .milliseconds(300))
      }
    )
  }

  /// Bound and listening, with nothing accepting until the test does.
  private func listening() throws -> (listener: Int32, path: URL) {
    let path = Scratch.socketPath("srv")
    let listener = try UnixSocket.newSocket(reportingAs: path.path)
    try UnixSocket.bindSocket(listener, to: path.path)
    try #require(listen(listener, 1) == 0)
    return (listener, path)
  }

  /// `call` on a thread of its own, `true` where it threw `SocketNoAnswer` in time.
  private func runsOutOfTime(
    within seconds: Double,
    _ call: @escaping @Sendable () throws -> Void,
  ) -> Bool {
    let outcome = Recorder<Bool>()
    let finished = DispatchSemaphore(value: 0)
    Thread.detachNewThread {
      do {
        try call()
        outcome.record(false)
      } catch {
        outcome.record(error is SocketNoAnswer)
      }
      finished.signal()
    }
    return finished.wait(timeout: .now() + seconds) == .success && outcome.received == [true]
  }

  /// Every byte the client left in the connection before it closed its end.
  private func bytesUntilTheEnd(of connection: Int32) -> Int {
    var chunk = [UInt8](repeating: 0, count: 4_096)
    var total = 0
    while true {
      let count = read(connection, &chunk, chunk.count)
      guard count > 0 else { return total }
      total += count
    }
  }
}
