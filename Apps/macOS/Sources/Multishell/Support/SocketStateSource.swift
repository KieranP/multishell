import Foundation
import MultishellCore
import MultishellProcess

/// `SessionStateSource` over the Unix socket in the state directory.
///
/// The server's handlers run on the main queue, so a line arrives in the
/// order it was sent and lands on the main actor without a hop. A line that
/// is not a report is dropped here.
@MainActor
final class SocketStateSource: SessionStateSource {
  var onReport: (@MainActor (SessionStateReport) -> Void)?

  private let server: UnixSocketServer

  init(path: URL = Paths.socketFile) {
    server = UnixSocketServer(path: path, queue: .main)
    server.onLine = { [weak self] line in
      MainActor.assumeIsolated {
        guard let self, let report = SessionStateReport.parse(line) else { return }
        self.onReport?(report)
      }
    }
  }

  func start() throws {
    try server.start()
  }

  func stop() {
    server.stop()
  }
}

/// For tests and for a platform without a channel yet.
@MainActor
final class NullStateSource: SessionStateSource {
  var onReport: (@MainActor (SessionStateReport) -> Void)?
  func start() throws {}
  func stop() {}
}
