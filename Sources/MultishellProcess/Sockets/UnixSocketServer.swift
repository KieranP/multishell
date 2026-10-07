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

  struct State {
    var listener: (any DispatchSourceRead)?
    var connections: [Int32: Connection] = [:]
    var isListenerSuspended = false
  }

  let path: String
  let claim: SocketClaim
  let queue: DispatchQueue
  let state = Mutex(State())
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
    guard staging.utf8.count <= UnixSocket.maximumPathLength else {
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
        state.isListenerSuspended = false
      }
      // Put back before it goes: a source released while suspended traps,
      // and its cancel handler, which closes the descriptor, never runs.
      if state.isListenerSuspended { state.listener?.resume() }
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
}
