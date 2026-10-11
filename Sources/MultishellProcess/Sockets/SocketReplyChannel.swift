import Foundation

/// The connection a line arrived on. Good only while `onLine` runs: the
/// server closes the descriptor at the client's EOF, often straight after.
public struct SocketReplyChannel: Sendable {
  let descriptor: Int32
  let connection: UnixSocketServer.Connection

  /// A reply that outlives the connection, or `nil` where no descriptor is
  /// free. A duplicate, so the server closing its own leaves this one open.
  public func open() -> SocketReply? {
    let copy = dup(descriptor)
    guard copy >= 0 else { return nil }
    return SocketReply(descriptor: copy, writingOn: connection.replies)
  }
}
