import Foundation

/// A request whose answer did not come back in time. Only the helper asks,
/// so no alert in the app words it.
public struct SocketNoAnswer: Error, CustomStringConvertible, Sendable, Equatable {
  let path: String
  let timeout: Duration

  public var description: String {
    "no answer on \(path) within \(String(format: "%g", timeout.inSeconds)) seconds"
  }
}
