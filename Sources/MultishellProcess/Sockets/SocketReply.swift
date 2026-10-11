import Foundation
import Synchronization

/// One answer down a connection, written off the caller's queue and then
/// closed. Dropped unsent it closes too, which the client reads as no answer.
public final class SocketReply: Sendable {
  /// How long a client that stopped reading may hold the write up. A slow one
  /// still reading may take longer: a screenshot's line runs to megabytes.
  private static let defaultStallTimeout: Duration = .seconds(5)
  /// Concurrent across connections: a client that stopped reading holds up
  /// only its own answers.
  private static let queue = DispatchQueue(
    label: "multishell.socket.replies",
    attributes: .concurrent,
  )

  /// No event says a client closed after its half-close, so the reply asks.
  private static let hangUpPollInterval: DispatchTimeInterval = .milliseconds(250)

  private let descriptor: Mutex<Int32>
  private let stallTimeout: Duration
  private let replyQueue: DispatchQueue
  private let hangUpWatch = Mutex<(any DispatchSourceTimer)?>(nil)

  init(
    descriptor: Int32,
    writingOn replyQueue: DispatchQueue = connectionQueue(),
    stallTimeout: Duration = defaultStallTimeout,
  ) {
    self.descriptor = Mutex(descriptor)
    self.replyQueue = replyQueue
    self.stallTimeout = stallTimeout
    UnixSocket.suppressSIGPIPE(on: descriptor)
  }

  /// Serial, one a connection: two answers written at once on one socket
  /// interleave their bytes.
  static func connectionQueue() -> DispatchQueue {
    DispatchQueue(label: "multishell.socket.connection-replies", target: queue)
  }

  /// The duplicate shares the connection's O_NONBLOCK, so a full buffer
  /// waits in `poll` rather than in `write`.
  private static func write(_ bytes: [UInt8], to descriptor: Int32, stallTimeout: Duration) {
    try? UnixSocket.write(
      bytes,
      to: descriptor,
      until: SocketDeadline(after: stallTimeout),
      renewingOnProgress: true,
    )
  }

  /// `onHangUp` once, should the client close before the answer is sent: a
  /// helper killed mid-request. Its half-close after the request is not one.
  public func watchForHangUp(_ onHangUp: @escaping @Sendable () -> Void) {
    let timer = DispatchSource.makeTimerSource(queue: replyQueue)
    timer.schedule(
      deadline: .now() + Self.hangUpPollInterval,
      repeating: Self.hangUpPollInterval,
    )
    timer.setEventHandler { [weak self] in
      guard let self, self.clientHasHungUp() else { return }
      self.stopWatchingForHangUp()
      onHangUp()
    }
    hangUpWatch.withLock { watch in
      watch?.cancel()
      watch = timer
    }
    timer.resume()
  }

  /// macOS sets POLLHUP only once both halves are shut; tested in SocketReplyTests.
  private func clientHasHungUp() -> Bool {
    descriptor.withLock { held in
      guard held >= 0 else { return false }
      var poller = pollfd(fd: held, events: Int16(POLLOUT), revents: 0)
      return poll(&poller, 1, 0) > 0 && poller.revents & Int16(POLLHUP) != 0
    }
  }

  private func stopWatchingForHangUp() {
    hangUpWatch.withLock { watch in
      watch?.cancel()
      watch = nil
    }
  }

  public func send(_ text: String) {
    stopWatchingForHangUp()
    guard let descriptor = take() else { return }
    let stallTimeout = stallTimeout
    replyQueue.async {
      Self.write(Array(text.utf8), to: descriptor, stallTimeout: stallTimeout)
      close(descriptor)
    }
  }

  private func take() -> Int32? {
    descriptor.withLock { held in
      defer { held = -1 }
      return held >= 0 ? held : nil
    }
  }

  deinit {
    stopWatchingForHangUp()
    if let descriptor = take() { close(descriptor) }
  }
}
