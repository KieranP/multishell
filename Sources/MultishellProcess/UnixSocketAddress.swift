import Foundation

/// `sockaddr_un` for a path, and the constants that differ by libc.
enum UnixSocketAddress {
  /// Bytes a path may have: `sun_path` less its terminator.
  static let capacity = MemoryLayout.size(ofValue: sockaddr_un().sun_path) - 1

  static func make(_ path: String) throws -> sockaddr_un {
    var address = sockaddr_un()
    let bytes = Array(path.utf8)
    guard bytes.count <= capacity else {
      throw SocketFailure(kind: .pathTooLong, path: path)
    }
    address.sun_family = sa_family_t(AF_UNIX)
    withUnsafeMutableBytes(of: &address.sun_path) { destination in
      destination.copyBytes(from: bytes)
    }
    return address
  }

  static var length: socklen_t { socklen_t(MemoryLayout<sockaddr_un>.size) }

  static var streamType: Int32 {
    SOCK_STREAM
  }

  static func newSocket(path: String) throws -> Int32 {
    let descriptor = socket(AF_UNIX, streamType, 0)
    guard descriptor >= 0 else {
      throw SocketFailure(kind: .system(operation: "socket", code: errno), path: path)
    }
    // A write to a peer that has gone would otherwise kill the process
    // with SIGPIPE.
    var on: Int32 = 1
    setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
    return descriptor
  }

  static func connectSocket(_ descriptor: Int32, to path: String) throws {
    var address = try make(path)
    let result = withUnsafePointer(to: &address) { pointer in
      pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        connect(descriptor, $0, length)
      }
    }
    guard result == 0 else {
      throw SocketFailure(kind: .system(operation: "connect", code: errno), path: path)
    }
  }

  static func bindSocket(_ descriptor: Int32, to path: String) throws {
    var address = try make(path)
    let result = withUnsafePointer(to: &address) { pointer in
      pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        bind(descriptor, $0, length)
      }
    }
    guard result == 0 else {
      throw SocketFailure(kind: .system(operation: "bind", code: errno), path: path)
    }
  }

  static func setNonBlocking(_ descriptor: Int32) {
    let flags = fcntl(descriptor, F_GETFL)
    _ = fcntl(descriptor, F_SETFL, flags | O_NONBLOCK)
  }
}
