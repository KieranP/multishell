import Foundation
import Synchronization

/// Listens on a Unix socket and hands each line to `onLine`. Handler-driven,
/// so no thread waits; the file is mode 0600 and its lines move a dot.
public final class UnixSocketServer: Sendable {
  public var onLine: (@Sendable (String) -> Void)? {
    get { lineHandler.withLock { $0 } }
    set { lineHandler.withLock { $0 = newValue } }
  }

  /// A connection that sends more than this without a newline is not
  /// speaking the protocol and is dropped.
  static let maximumLineLength = 64 * 1024

  private struct State {
    var listener: (any DispatchSourceRead)?
    var connections: [Int32: Connection] = [:]
    /// Whether the listener is suspended waiting for a descriptor to free.
    var listenerSuspended = false
  }

  let path: String
  let claim: SocketClaim
  private let queue: DispatchQueue
  private let state = Mutex(State())
  private let lineHandler = Mutex<(@Sendable (String) -> Void)?>(nil)

  public init(path: URL, queue: DispatchQueue = DispatchQueue(label: "multishell.socket")) {
    self.path = path.path
    claim = SocketClaim(socketPath: path.path)
    self.queue = queue
  }

  deinit { stop() }

  /// A crashed instance's socket file is unlinked, but only once nothing
  /// holds the claim beside it and a connect is refused.
  public func start() throws {
    // Already listening. The probe would find this instance answering, read
    // it as another, and the failure path would let go of a claim still needed.
    guard state.withLock({ $0.listener == nil }) else { return }
    try FileManager.default.createDirectory(
      at: URL(fileURLWithPath: path).deletingLastPathComponent(),
      withIntermediateDirectories: true)
    try claim.takeOrRefuse()
    // A start that failed is not listening, and a claim says the opposite,
    // so it goes back before the failure is reported.
    do {
      try listenOnceClaimed()
    } catch {
      claim.release()
      throw error
    }
  }

  private func listenOnceClaimed() throws {
    try probeAndUnlinkStale()
    let descriptor = try bindAndListen()
    DescriptorFlags.setNonBlocking(descriptor)

    let source = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: queue)
    source.setEventHandler { [weak self] in self?.acceptPending(on: descriptor) }
    source.setCancelHandler { close(descriptor) }
    state.withLock { $0.listener = source }
    source.resume()
  }

  /// The listening descriptor, at `path` with mode 0600. Every failure closes
  /// what it opened and leaves no file behind.
  private func bindAndListen() throws -> Int32 {
    // Bound beside the socket and renamed in, so the path is never briefly
    // world-readable: the mode is the umask's, and umask is process-wide.
    let staging = path + ".b"
    // The staging name is what binds, so its length is the limit. The alert
    // names the socket; see Docs/develop/state-on-disk.md for the two bytes.
    guard staging.utf8.count <= UnixSocket.capacity else {
      throw SocketFailure(kind: .pathTooLong, path: path)
    }
    let descriptor = try UnixSocket.newSocket(reportingAs: staging)
    do {
      unlink(staging)
      try UnixSocket.bindSocket(descriptor, to: staging)
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
    return descriptor
  }

  public func stop() {
    let (listener, connections) = state.withLock { state in
      defer {
        state.listener = nil
        state.connections.removeAll()
        state.listenerSuspended = false
      }
      // Put back before it goes: a source released while suspended traps,
      // and its cancel handler, which closes the descriptor, never runs.
      if state.listenerSuspended { state.listener?.resume() }
      return (state.listener, Array(state.connections.values))
    }
    // After the socket file has gone, so a launch taking the claim in between
    // finds nothing to probe rather than this instance answering on its way out.
    defer { claim.release() }
    guard listener != nil else { return }
    listener?.cancel()
    for connection in connections {
      connection.source.cancel()
    }
    unlink(path)
  }

  private func probeAndUnlinkStale() throws {
    guard FileManager.default.fileExists(atPath: path) else { return }
    let probe = try UnixSocket.newSocket(reportingAs: path)
    defer { close(probe) }
    do {
      try UnixSocket.connectSocket(probe, to: path)
      throw SocketFailure(kind: .inUse, path: path)
    } catch let failure as SocketFailure where failure.kind != .inUse {
      // Refused, or not a socket at all, and the claim is ours: nobody is
      // behind it.
      unlink(path)
    }
  }

  /// How long the listener stays suspended when there is no descriptor to
  /// accept with. Long enough that the queue is not the thing holding one.
  private static let descriptorBackoff: DispatchTimeInterval = .milliseconds(250)

  private func acceptPending(on descriptor: Int32) {
    while true {
      let client = accept(descriptor, nil, nil)
      guard client >= 0 else {
        switch AcceptOutcome(errno: errno) {
        case .waitForNextEvent: return
        case .again: continue
        case .outOfDescriptors:
          // The pending connection stays in the backlog and the source is
          // level-triggered, so returning here burns a core until one frees.
          suspendListenerForBackoff()
          return
        }
      }
      DescriptorFlags.setNonBlocking(client)
      let source = DispatchSource.makeReadSource(fileDescriptor: client, queue: queue)
      let connection = Connection(source: source)
      source.setEventHandler { [weak self] in self?.readLines(from: client, into: connection) }
      source.setCancelHandler { close(client) }
      state.withLock { $0.connections[client] = connection }
      source.resume()
    }
  }

  /// Suspends the listener and brings it back once, all under the lock:
  /// releasing a suspended source traps, and so does one resume too many.
  private func suspendListenerForBackoff() {
    let suspended = state.withLock { state -> Bool in
      guard !state.listenerSuspended, let source = state.listener else { return false }
      state.listenerSuspended = true
      source.suspend()
      return true
    }
    guard suspended else { return }
    queue.asyncAfter(deadline: .now() + Self.descriptorBackoff) { [weak self] in
      guard let self else { return }
      self.state.withLock { state in
        guard state.listenerSuspended, let source = state.listener else { return }
        state.listenerSuspended = false
        source.resume()
      }
    }
  }

  private func readLines(from descriptor: Int32, into connection: Connection) {
    let onLine = onLine
    var chunk = [UInt8](repeating: 0, count: 4096)
    while true {
      let count = read(descriptor, &chunk, chunk.count)
      if count > 0 {
        connection.buffer.append(contentsOf: chunk[0..<count])
        while let newline = connection.buffer.firstIndex(of: UInt8(ascii: "\n")) {
          onLine?(String(decoding: connection.buffer[..<newline], as: UTF8.self))
          connection.buffer.removeSubrange(...newline)
        }
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

  private func drop(_ descriptor: Int32, _ connection: Connection) {
    state.withLock { $0.connections[descriptor] = nil }
    connection.source.cancel()
  }

  /// Unchecked: `buffer` is touched only by its read source's handler, which
  /// runs on the server's serial queue.
  private final class Connection: @unchecked Sendable {
    let source: any DispatchSourceRead
    var buffer: [UInt8] = []
    init(source: any DispatchSourceRead) { self.source = source }
  }
}
