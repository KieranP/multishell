import Foundation
import MultishellCore
import MultishellProcess

/// `SessionStateSource` over the Unix socket in the state directory. Handlers
/// run on the main queue, so lines arrive in order and without a hop.
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
