import Foundation
import MultishellCore
import MultishellProcess
import Synchronization
import TestScratch

@testable import MultishellCLI

/// A socket standing in for the app, keeping each request and answering
/// with what `answer` gives it, or with nothing for `nil`, as an older app does.
final class ControlListener: Sendable {
  let path = Scratch.socketPath("ctl")
  let requests = Recorder<ControlRequest>()
  private let server: UnixSocketServer

  var environment: [String: String] { [Helper.controlSocketVariable: path.path] }

  convenience init(reply: ControlReply?) throws {
    try self.init { _ in reply }
  }

  init(answering answer: @escaping @Sendable (ControlRequest) -> ControlReply?) throws {
    server = UnixSocketServer(path: path)
    server.onLine = { [requests] line, channel in
      guard let request = ControlRequest.parse(line) else { return }
      requests.record(request)
      guard let reply = answer(request), let replying = channel.open() else { return }
      replying.send((try? reply.encodedLine()) ?? "")
    }
    try server.start()
  }

  /// `answer` is told how many requests came before this one.
  static func answeringInTurn(
    _ answer: @escaping @Sendable (Int) -> ControlReply?
  ) throws -> ControlListener {
    let turns = Mutex(0)
    return try ControlListener { _ in
      answer(
        turns.withLock { count in
          defer { count += 1 }
          return count
        }
      )
    }
  }

  func stop() {
    server.stop()
    Scratch.removeSocket(path)
  }
}
