import Synchronization

/// A box for `withObservationTracking`, whose `@Sendable` callback can
/// neither capture a mutable local nor be trusted to run on one thread.
final class Flag: Sendable {
  private let value = Atomic(false)

  init() {}

  var raised: Bool { value.load(ordering: .acquiring) }
  func raise() { value.store(true, ordering: .releasing) }
}
