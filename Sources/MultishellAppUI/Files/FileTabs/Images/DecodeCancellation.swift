import Synchronization

/// Raised when a decode's task is cancelled, read by the queued work before it
/// starts: a cancelled task cannot stop work already handed to Dispatch.
final class DecodeCancellation: Sendable {
  private let value = Atomic(false)

  var isRaised: Bool { value.load(ordering: .acquiring) }

  func raise() { value.store(true, ordering: .releasing) }
}
