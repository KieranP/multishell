import Foundation
import MultishellCore
import MultishellProcess

/// `SessionStateSource` over the Unix socket in the state directory, for any
/// platform that has one.
///
/// The server's handlers run on the main queue, so a line arrives in the
/// order it was sent and lands on the main actor without a hop. A line that
/// is not a report is dropped here.
@MainActor
public final class SocketStateSource: SessionStateSource {
  public var onReport: (@MainActor (SessionStateReport) -> Void)?

  private let server: UnixSocketServer

  public init(path: URL = Paths.socketFile) {
    server = UnixSocketServer(path: path, queue: .main)
    server.onLine = { [weak self] line in
      MainActor.assumeIsolated {
        guard let self, let report = SessionStateReport.parse(line) else { return }
        self.onReport?(report)
      }
    }
  }

  public func start() throws {
    try server.start()
  }

  public func stop() {
    server.stop()
  }
}
