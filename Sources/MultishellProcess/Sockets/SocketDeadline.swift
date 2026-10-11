import Foundation

/// The time a whole exchange on a socket has, waited out in `poll` on a
/// non-blocking descriptor: a blocking call's own limit restarts on every byte.
struct SocketDeadline {
  let timeout: Duration
  private let end: ContinuousClock.Instant

  init(after timeout: Duration) {
    self.timeout = timeout
    end = .now + timeout
  }

  /// `false` once the time is up before `descriptor` is ready for `event`.
  func waitUntil(_ descriptor: Int32, isReadyFor event: Int32) -> Bool {
    let remaining = ContinuousClock.now.duration(to: end)
    guard remaining > .zero else { return false }
    var ready = pollfd(fd: descriptor, events: Int16(event), revents: 0)
    return poll(&ready, 1, Int32(remaining.inMilliseconds) + 1) != 0
  }
}
