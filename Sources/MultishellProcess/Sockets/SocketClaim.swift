import Foundation
import Synchronization

/// Held for as long as a server listens. An `fcntl` record lock dies with the
/// process, so holding it is what says the socket's owner is alive.
final class SocketClaim: Sendable {
  /// The file whose lock says the socket has a live owner. Beside the socket,
  /// and never unlinked: see Docs/develop/state-on-disk.md.
  let lockFilePath: String
  private let socketPath: String
  private let descriptor = Mutex<Int32>(-1)

  init(socketPath: String) {
    self.socketPath = socketPath
    lockFilePath = socketPath + ".lock"
  }

  /// Takes the claim, or refuses to start: a connect alone cannot tell a live
  /// listener with a full backlog from a dead socket; see state-on-disk.md.
  func takeOrRefuse() throws {
    guard descriptor.withLock({ $0 < 0 }) else { return }
    let opened = open(lockFilePath, O_CREAT | O_RDWR | O_CLOEXEC, 0o600)
    // A filesystem that will not lock leaves the probe to decide, as before.
    guard opened >= 0 else { return }
    var record = flock(
      l_start: 0, l_len: 0, l_pid: 0, l_type: Int16(F_WRLCK), l_whence: Int16(SEEK_SET))
    guard fcntl(opened, F_SETLK, &record) == 0 else {
      let code = errno
      close(opened)
      guard code == EAGAIN || code == EACCES else { return }
      throw SocketFailure(kind: .inUse, path: socketPath)
    }
    descriptor.withLock { $0 = opened }
  }

  /// Closing it drops the lock; the file stays, as an empty one is what the
  /// next launch expects to find.
  func release() {
    descriptor.withLock { held in
      if held >= 0 { close(held) }
      held = -1
    }
  }
}
