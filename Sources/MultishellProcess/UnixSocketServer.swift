import Foundation

/// Listens on a Unix socket and hands each newline-terminated line to
/// `onLine`, from whatever connection it arrived on.
///
/// Handler-driven: accepts and reads happen in `DispatchSource` handlers on
/// `queue`, so no thread waits. The socket file is created mode 0600 and
/// belongs to the user; anything that can write to it could already run
/// commands as them, and the lines it accepts change a dot and nothing else.
public final class UnixSocketServer: @unchecked Sendable {
  public var onLine: (@Sendable (String) -> Void)?

  /// A connection that sends more than this without a newline is not
  /// speaking the protocol and is dropped.
  public static let maximumLineLength = 64 * 1024

  private let path: String
  private let queue: DispatchQueue
  private let lock = NSLock()
  private var listener: (any DispatchSourceRead)?
  private var connections: [Int32: Connection] = [:]

  public init(path: URL, queue: DispatchQueue = DispatchQueue(label: "multishell.socket")) {
    self.path = path.path
    self.queue = queue
  }

  deinit { stop() }

  /// A socket file left by an instance that crashed is unlinked first, but
  /// only after a connect to it is refused: one that answers belongs to a
  /// running instance, and stealing its path would leave that instance deaf
  /// without anyone knowing.
  public func start() throws {
    #if os(Windows)
      throw SocketFailure(kind: .unsupportedPlatform, path: path)
    #else
      try probeAndUnlinkStale()
      try FileManager.default.createDirectory(
        at: URL(fileURLWithPath: path).deletingLastPathComponent(),
        withIntermediateDirectories: true)

      let descriptor = try UnixSocketAddress.newSocket(path: path)
      do {
        try UnixSocketAddress.bindSocket(descriptor, to: path)
      } catch {
        close(descriptor)
        throw error
      }
      chmod(path, 0o600)
      guard listen(descriptor, 16) == 0 else {
        let code = errno
        close(descriptor)
        unlink(path)
        throw SocketFailure(kind: .system(operation: "listen", code: code), path: path)
      }
      UnixSocketAddress.setNonBlocking(descriptor)

      let source = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: queue)
      source.setEventHandler { [weak self] in self?.acceptPending(on: descriptor) }
      source.setCancelHandler { close(descriptor) }
      lock.withLock { listener = source }
      source.resume()
    #endif
  }

  public func stop() {
    let (listener, connections) = lock.withLock {
      defer {
        self.listener = nil
        self.connections.removeAll()
      }
      return (self.listener, Array(self.connections.values))
    }
    guard listener != nil else { return }
    listener?.cancel()
    for connection in connections {
      connection.source.cancel()
    }
    #if !os(Windows)
      unlink(path)
    #endif
  }

  #if !os(Windows)
    private func probeAndUnlinkStale() throws {
      guard FileManager.default.fileExists(atPath: path) else { return }
      let probe = try UnixSocketAddress.newSocket(path: path)
      defer { close(probe) }
      do {
        try UnixSocketAddress.connectSocket(probe, to: path)
        throw SocketFailure(kind: .inUse, path: path)
      } catch let failure as SocketFailure where failure.kind != .inUse {
        // Refused, or not a socket at all: nobody is behind it.
        unlink(path)
      }
    }

    private func acceptPending(on descriptor: Int32) {
      while true {
        let client = accept(descriptor, nil, nil)
        guard client >= 0 else { return }
        UnixSocketAddress.setNonBlocking(client)
        let source = DispatchSource.makeReadSource(fileDescriptor: client, queue: queue)
        let connection = Connection(source: source)
        source.setEventHandler { [weak self] in self?.drain(client, into: connection) }
        source.setCancelHandler { close(client) }
        lock.withLock { connections[client] = connection }
        source.resume()
      }
    }

    private func drain(_ descriptor: Int32, into connection: Connection) {
      var chunk = [UInt8](repeating: 0, count: 4096)
      while true {
        let count = read(descriptor, &chunk, chunk.count)
        if count > 0 {
          connection.buffer.append(contentsOf: chunk[0..<count])
          deliverLines(from: connection)
          if connection.buffer.count > Self.maximumLineLength {
            drop(descriptor, connection)
            return
          }
        } else if count == 0 {
          // EOF. A client that wrote one line and closed without a newline
          // still meant it.
          if !connection.buffer.isEmpty {
            onLine?(String(decoding: connection.buffer, as: UTF8.self))
            connection.buffer.removeAll()
          }
          drop(descriptor, connection)
          return
        } else {
          if errno == EAGAIN || errno == EWOULDBLOCK { return }
          if errno == EINTR { continue }
          drop(descriptor, connection)
          return
        }
      }
    }

    private func deliverLines(from connection: Connection) {
      while let newline = connection.buffer.firstIndex(of: UInt8(ascii: "\n")) {
        let line = String(decoding: connection.buffer[..<newline], as: UTF8.self)
        connection.buffer.removeSubrange(...newline)
        onLine?(line)
      }
    }

    private func drop(_ descriptor: Int32, _ connection: Connection) {
      lock.withLock { connections[descriptor] = nil }
      connection.source.cancel()
    }
  #endif

  private final class Connection {
    let source: any DispatchSourceRead
    var buffer: [UInt8] = []
    init(source: any DispatchSourceRead) { self.source = source }
  }
}
