import Foundation

/// Connects, writes, and for a request reads the answer to EOF. Blocking, and
/// meant for a command-line helper whose whole job this is; the app never calls it.
public enum UnixSocketClient {
  /// `timeout` nil waits as long as the listener takes to read it.
  public static func send(_ text: String, to path: URL, timeout: Duration? = nil) throws {
    let path = path.path
    let descriptor = try connected(to: path)
    defer { close(descriptor) }
    let deadline = deadline(timeout, on: descriptor)
    try write(text, to: descriptor, path: path, deadline: deadline)
  }

  /// Writes `text`, closes the writing half, and reads to EOF: empty where the
  /// listener closed without an answer. `timeout` nil waits as long as it takes.
  public static func request(_ text: String, to path: URL, timeout: Duration?) throws -> String {
    let path = path.path
    let descriptor = try connected(to: path)
    defer { close(descriptor) }
    let deadline = deadline(timeout, on: descriptor)
    try write(text, to: descriptor, path: path, deadline: deadline)
    shutdown(descriptor, SHUT_WR)

    var answer: [UInt8] = []
    var chunk = [UInt8](repeating: 0, count: 4096)
    while true {
      let count = read(descriptor, &chunk, chunk.count)
      if count > 0 {
        answer += chunk[0..<count]
      } else if count == 0 {
        return String(decoding: answer, as: UTF8.self)
      } else if let deadline, errno == EAGAIN || errno == EWOULDBLOCK {
        try wait(for: POLLIN, on: descriptor, until: deadline, path: path)
      } else if errno != EINTR {
        throw SocketFailure(kind: .system(operation: "read", code: errno), path: path)
      }
    }
  }

  /// Non-blocking under a deadline, so each wait is the deadline's `poll`.
  private static func deadline(_ timeout: Duration?, on descriptor: Int32) -> SocketDeadline? {
    guard let timeout else { return nil }
    DescriptorFlags.setNonBlocking(descriptor)
    return SocketDeadline(after: timeout)
  }

  private static func wait(
    for event: Int32,
    on descriptor: Int32,
    until deadline: SocketDeadline,
    path: String,
  ) throws {
    guard deadline.waitUntil(descriptor, isReadyFor: event) else {
      throw SocketNoAnswer(path: path, timeout: deadline.timeout)
    }
  }

  private static func connected(to path: String) throws -> Int32 {
    let descriptor = try UnixSocket.newSocket(reportingAs: path)
    do {
      try UnixSocket.connectSocket(descriptor, to: path)
    } catch {
      close(descriptor)
      throw error
    }
    return descriptor
  }

  private static func write(
    _ text: String,
    to descriptor: Int32,
    path: String,
    deadline: SocketDeadline?,
  ) throws {
    do {
      try UnixSocket.write(Array(text.utf8), to: descriptor, until: deadline)
    } catch .timedOut(let timeout) {
      throw SocketNoAnswer(path: path, timeout: timeout)
    } catch .system(let code) {
      throw SocketFailure(kind: .system(operation: "write", code: code), path: path)
    }
  }
}
