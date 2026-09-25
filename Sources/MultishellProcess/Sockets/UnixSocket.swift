import Foundation

/// `sockaddr_un` for a path, and the socket calls that take one.
enum UnixSocket {
  /// Bytes a path may have: `sun_path` less its terminator.
  static let capacity = MemoryLayout.size(ofValue: sockaddr_un().sun_path) - 1

  static func address(for path: String) throws -> sockaddr_un {
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

  static func newSocket(reportingAs path: String) throws -> Int32 {
    let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
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
    try call("connect", withAddressOf: path) { connect(descriptor, $0, length) }
  }

  static func bindSocket(_ descriptor: Int32, to path: String) throws {
    try call("bind", withAddressOf: path) { bind(descriptor, $0, length) }
  }

  /// `operation` names the call in the failure, which reads its errno.
  private static func call(
    _ operation: String, withAddressOf path: String, _ body: (UnsafePointer<sockaddr>) -> Int32
  ) throws {
    var socketAddress = try address(for: path)
    let result = withUnsafePointer(to: &socketAddress) { pointer in
      pointer.withMemoryRebound(to: sockaddr.self, capacity: 1, body)
    }
    guard result == 0 else {
      throw SocketFailure(kind: .system(operation: operation, code: errno), path: path)
    }
  }
}
