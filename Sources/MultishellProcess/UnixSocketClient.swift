import Foundation

/// Connects, writes, closes. Blocking, and meant for a command-line helper
/// whose whole job this is; the app never calls it.
public enum UnixSocketClient {
  public static func send(_ text: String, to path: URL) throws {
    #if os(Windows)
      throw SocketFailure(kind: .unsupportedPlatform, path: path.path)
    #else
      let path = path.path
      let descriptor = try UnixSocketAddress.newSocket(path: path)
      defer { close(descriptor) }
      try UnixSocketAddress.connectSocket(descriptor, to: path)

      let bytes = Array(text.utf8)
      var written = 0
      while written < bytes.count {
        let count = bytes[written...].withUnsafeBufferPointer { buffer in
          #if os(Linux)
            send(descriptor, buffer.baseAddress, buffer.count, Int32(MSG_NOSIGNAL))
          #else
            write(descriptor, buffer.baseAddress, buffer.count)
          #endif
        }
        if count < 0 {
          if errno == EINTR { continue }
          throw SocketFailure(kind: .system(operation: "write", code: errno), path: path)
        }
        written += count
      }
    #endif
  }
}
