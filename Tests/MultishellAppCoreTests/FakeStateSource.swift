import MultishellCore

/// A channel the test drives by hand.
@MainActor
final class FakeStateSource: SessionStateSource {
  var onReport: (@MainActor (SessionStateReport) -> Void)?
  var started = false
  /// Thrown by `start`, standing in for a socket another copy holds.
  var startError: (any Error)?
  func start() throws {
    if let startError { throw startError }
    started = true
  }
  func stop() { started = false }
  func send(_ report: SessionStateReport) { onReport?(report) }
}
