import Foundation
import Synchronization

extension UnixSocketServer {
  /// How long the listener stays suspended when there is no descriptor to
  /// accept with. Long enough that the queue is not the thing holding one.
  private static let resourceBackoff: DispatchTimeInterval = .milliseconds(250)

  func acceptPending(on descriptor: Int32) {
    while true {
      let client = accept(descriptor, nil, nil)
      guard client >= 0 else {
        switch AcceptOutcome(errno: errno) {
        case .waitForNextEvent: return
        case .retryNow: continue
        case .outOfResources:
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
      guard !state.isListenerSuspended, let source = state.listener else { return false }
      state.isListenerSuspended = true
      source.suspend()
      return true
    }
    guard suspended else { return }
    queue.asyncAfter(deadline: .now() + Self.resourceBackoff) { [weak self] in
      guard let self else { return }
      self.state.withLock { state in
        guard state.isListenerSuspended, let source = state.listener else { return }
        state.isListenerSuspended = false
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
        for line in connection.buffer.append(chunk[0..<count]) { onLine?(line) }
        if connection.buffer.pendingByteCount > Self.maximumLineLength {
          drop(descriptor, connection)
          return
        }
      } else if count == 0 {
        // EOF. A client that wrote one line and closed without a newline
        // still meant it.
        if let rest = connection.buffer.takeRest() { onLine?(rest) }
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
  final class Connection: @unchecked Sendable {
    let source: any DispatchSourceRead
    var buffer = LineBuffer()
    init(source: any DispatchSourceRead) { self.source = source }
  }
}
