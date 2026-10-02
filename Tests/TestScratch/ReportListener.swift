import Foundation
import MultishellProcess

/// A socket server standing in for the app, keeping every line it reads.
public final class ReportListener {
  public let path: URL
  public let recorder = Recorder<String>()
  private let server: UnixSocketServer

  public init(prefix: String = "cli") throws {
    path = Scratch.socketPath(prefix)
    server = UnixSocketServer(path: path)
    server.onLine = { [recorder] in recorder.record($0) }
    try server.start()
  }

  public func stop() {
    server.stop()
    Scratch.removeSocket(path)
  }
}
