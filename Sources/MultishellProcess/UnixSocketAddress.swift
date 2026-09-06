import Foundation

/// A failed socket call, with the operation and errno so the alert can say
/// what happened rather than "socket error".
public struct SocketFailure: Error, CustomStringConvertible, Sendable {
  public enum Kind: Sendable, Equatable {
    /// `sun_path` holds 104 bytes on Darwin and 108 on Linux; a state
    /// directory under a long home path can exceed it.
    case pathTooLong
    /// Another process answered on the socket: a second instance of the app.
    case inUse
    case system(operation: String, code: Int32)
  }

  public let kind: Kind
  public let path: String

  public var description: String {
    switch kind {
    case .pathTooLong:
      "\(path) is too long for a Unix socket address."
    case .inUse:
      "another process is already listening on \(path)."
    case .system(let operation, let code):
      "\(operation) on \(path) failed: \(String(cString: strerror(code))) (\(code))"
    }
  }
}

/// `sockaddr_un` for a path, and the constants that differ by libc.
enum UnixSocketAddress {
  static func make(_ path: String) throws -> sockaddr_un {
    var address = sockaddr_un()
    let capacity = MemoryLayout.size(ofValue: address.sun_path) - 1
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
    #if os(Linux)
      Int32(SOCK_STREAM.rawValue)
    #else
      SOCK_STREAM
    #endif
  }

  static func newSocket(path: String) throws -> Int32 {
    let descriptor = socket(AF_UNIX, streamType, 0)
    guard descriptor >= 0 else {
      throw SocketFailure(kind: .system(operation: "socket", code: errno), path: path)
    }
    #if !os(Linux)
      // A write to a peer that has gone would otherwise kill the process
      // with SIGPIPE; Linux takes MSG_NOSIGNAL on the send instead.
      var on: Int32 = 1
      setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
    #endif
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
