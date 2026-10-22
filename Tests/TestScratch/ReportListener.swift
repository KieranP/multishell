import Foundation
import MultishellProcess

/// A socket server standing in for the app, keeping every line it reads.
public final class ReportListener {
  public let path: URL
  public let recorder = Recorder<String>()
  private let server: UnixSocketServer

  public init(tag: String = "cli") throws {
    path = Scratch.socketPath(tag)
    server = UnixSocketServer(path: path)
    server.onLine = { [recorder] line, _ in recorder.record(line) }
    try server.start()
  }

  public func stop() {
    server.stop()
    Scratch.removeSocket(path)
  }
}
