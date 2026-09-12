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
  /// Held for as long as this instance listens. `flock` goes with the
  /// process, so holding it is what says the owner of the socket is alive.
  private var claim: Int32 = -1
  private var listener: (any DispatchSourceRead)?
  private var connections: [Int32: Connection] = [:]
  /// Whether the listener is suspended waiting for a descriptor to free.
  private var standingDown = false

  public init(path: URL, queue: DispatchQueue = DispatchQueue(label: "multishell.socket")) {
    self.path = path.path
    self.queue = queue
  }

  deinit { stop() }

  /// A crashed instance's socket file is unlinked, but only once nothing
  /// holds the claim beside it and a connect is refused.
  public func start() throws {
    try FileManager.default.createDirectory(
      at: URL(fileURLWithPath: path).deletingLastPathComponent(),
      withIntermediateDirectories: true)
    try claimOrRefuse()
    // A start that failed is not listening, and a claim says the opposite,
    // so it goes back before the failure is reported.
    do {
      try listenOnceClaimed()
    } catch {
      releaseClaim()
      throw error
    }
  }

  private func listenOnceClaimed() throws {
    try probeAndUnlinkStale()

    // Bound beside the socket and renamed in, so the path is never briefly
    // world-readable: the mode is the umask's, and umask is process-wide.
    let staging = path + ".b"
    // Against the real path, so a path near the address limit is refused
    // for its own length rather than for the staging name's.
    _ = try UnixSocketAddress.make(path)
    let descriptor = try UnixSocketAddress.newSocket(path: staging)
    do {
      unlink(staging)
      try UnixSocketAddress.bindSocket(descriptor, to: staging)
    } catch {
      close(descriptor)
      throw error
    }
    chmod(staging, 0o600)
    guard rename(staging, path) == 0 else {
      let code = errno
      close(descriptor)
      unlink(staging)
      throw SocketFailure(kind: .system(operation: "rename", code: code), path: path)
    }
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
    // After the socket file has gone, so a launch that takes the claim in
    // between finds nothing to probe rather than this instance still
    // answering on its way out.
    defer { releaseClaim() }
    guard listener != nil else { return }
    listener?.cancel()
    for connection in connections {
      connection.source.cancel()
    }
    unlink(path)
  }

  /// The file whose lock says this socket has a live owner. Beside the
  /// socket, and never unlinked: see docs/develop/state-on-disk.md.
  var claimPath: String { path + ".lock" }

  /// Takes the claim, or refuses to start. A running instance whose accept
  /// backlog is full refuses a connect exactly as a dead one's socket does,
  /// so the probe alone would unlink a live socket; the claim cannot.
  ///
  /// An `fcntl` record lock rather than `flock`: a child forked while an
  /// `flock` is held keeps it until it execs, and this process spawns freely.
  private func claimOrRefuse() throws {
    guard lock.withLock({ claim < 0 }) else { return }
    let descriptor = open(claimPath, O_CREAT | O_RDWR | O_CLOEXEC, 0o600)
    // A filesystem that will not lock leaves the probe to decide, as before.
    guard descriptor >= 0 else { return }
    var record = flock(
      l_start: 0, l_len: 0, l_pid: 0, l_type: Int16(F_WRLCK), l_whence: Int16(SEEK_SET))
    guard fcntl(descriptor, F_SETLK, &record) == 0 else {
      let code = errno
      close(descriptor)
      guard code == EAGAIN || code == EACCES else { return }
      throw SocketFailure(kind: .inUse, path: path)
    }
    lock.withLock { claim = descriptor }
  }

  /// Closing it drops the lock; the file stays, as an empty one is what the
  /// next launch expects to find.
  private func releaseClaim() {
    lock.withLock {
      if claim >= 0 { close(claim) }
      claim = -1
    }
  }

  private func probeAndUnlinkStale() throws {
    guard FileManager.default.fileExists(atPath: path) else { return }
    let probe = try UnixSocketAddress.newSocket(path: path)
    defer { close(probe) }
    do {
      try UnixSocketAddress.connectSocket(probe, to: path)
      throw SocketFailure(kind: .inUse, path: path)
    } catch let failure as SocketFailure where failure.kind != .inUse {
      // Refused, or not a socket at all, and the claim is ours: nobody is
      // behind it.
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

  /// Suspends the listener and brings it back once, all under the lock:
  /// releasing a suspended source traps, and so does one resume too many.
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
