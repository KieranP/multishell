import Foundation

/// Listens on a Unix socket and hands each line to `onLine`. Handler-driven,
/// so no thread waits; the file is mode 0600 and its lines move a dot.
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
  /// Whether the listener is suspended waiting for a descriptor to free.
  private var standingDown = false

  public init(path: URL, queue: DispatchQueue = DispatchQueue(label: "multishell.socket")) {
    self.path = path.path
    self.queue = queue
  }

  deinit { stop() }

  /// A crashed instance's socket file is unlinked, but only after a connect
  /// is refused: one that answers belongs to a running instance.
  public func start() throws {
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
  }

  public func stop() {
    let (listener, connections) = lock.withLock {
      defer {
        self.listener = nil
        self.connections.removeAll()
        self.standingDown = false
      }
      // Put back before it goes: a source released while suspended traps,
      // and its cancel handler, which closes the descriptor, never runs.
      if standingDown { self.listener?.resume() }
      return (self.listener, Array(self.connections.values))
    }
    guard listener != nil else { return }
    listener?.cancel()
    for connection in connections {
      connection.source.cancel()
    }
    unlink(path)
  }

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

  /// What a failed `accept` means. Every case but `drained` leaves the
  /// connection in the backlog, and the read source fires again on it.
  enum AcceptOutcome: Equatable {
    case drained
    case again
    case outOfDescriptors

    init(errno code: Int32) {
      switch code {
      case EINTR, ECONNABORTED, EPROTO: self = .again
      case EMFILE, ENFILE, ENOBUFS, ENOMEM: self = .outOfDescriptors
      default: self = .drained
      }
    }
  }

  /// How long the listener stands down for when there is no descriptor to
  /// accept with. Long enough that the queue is not the thing holding one.
  private static let descriptorBackoff: DispatchTimeInterval = .milliseconds(250)

  private func acceptPending(on descriptor: Int32) {
    while true {
      let client = accept(descriptor, nil, nil)
      guard client >= 0 else {
        switch AcceptOutcome(errno: errno) {
        case .drained: return
        case .again: continue
        case .outOfDescriptors:
          // The pending connection stays in the backlog and the source is
          // level-triggered, so returning here burns a core until one frees.
          standDown()
          return
        }
      }
      UnixSocketAddress.setNonBlocking(client)
      let source = DispatchSource.makeReadSource(fileDescriptor: client, queue: queue)
      let connection = Connection(source: source)
      source.setEventHandler { [weak self] in self?.drain(client, into: connection) }
      source.setCancelHandler { close(client) }
      lock.withLock { connections[client] = connection }
      source.resume()
    }
  }

  /// Suspends the listener and brings it back once. Every suspend and resume
  /// is under the lock: releasing a suspended source traps, and so does one
  /// resume too many, so `stop` has to see this state and undo it.
  private func standDown() {
    let suspended = lock.withLock { () -> Bool in
      guard !standingDown, let source = listener else { return false }
      standingDown = true
      source.suspend()
      return true
    }
    guard suspended else { return }
    queue.asyncAfter(deadline: .now() + Self.descriptorBackoff) { [weak self] in
      guard let self else { return }
      self.lock.withLock {
        guard self.standingDown, let source = self.listener else { return }
        self.standingDown = false
        source.resume()
      }
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

  private final class Connection {
    let source: any DispatchSourceRead
    var buffer: [UInt8] = []
    init(source: any DispatchSourceRead) { self.source = source }
  }
}
