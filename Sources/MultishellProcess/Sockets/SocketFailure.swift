import Foundation

/// A failed socket call, with the operation and errno so the alert can say
/// what happened rather than "socket error".
public struct SocketFailure: Error, CustomStringConvertible, Sendable {
  public enum Kind: Sendable, Equatable {
    /// `sun_path` holds 104 bytes; a state directory under a long home
    /// path can exceed it.
    case pathTooLong
    /// Another process holds the socket's lock file or answered on the socket:
    /// a second instance of the app.
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
