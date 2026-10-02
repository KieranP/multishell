import Foundation

extension UnixSocketServer {
  /// How long the listener stays suspended when there is no descriptor to
  /// accept with. Long enough that the queue is not the thing holding one.
  private static let descriptorBackoff: DispatchTimeInterval = .milliseconds(250)

  func acceptPending(on descriptor: Int32) {
    while true {
      let client = accept(descriptor, nil, nil)
      guard client >= 0 else {
        switch AcceptOutcome(errno: errno) {
        case .waitForNextEvent: return
        case .retryNow: continue
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
  final class Connection: @unchecked Sendable {
    let source: any DispatchSourceRead
    var buffer: [UInt8] = []
    init(source: any DispatchSourceRead) { self.source = source }
  }
}
