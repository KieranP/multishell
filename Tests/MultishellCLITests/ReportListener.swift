import MultishellProcess
import TestScratch

/// A socket server standing in for the app, keeping every line it reads.
final class ReportListener {
  let path = Scratch.socketPath("cli")
  let recorder = LineRecorder()
  private let server: UnixSocketServer

  init() throws {
    server = UnixSocketServer(path: path)
    server.onLine = { [recorder] in recorder.record($0) }
    try server.start()
  }

  func stop() {
    server.stop()
    Scratch.removeSocket(path)
  }
}
