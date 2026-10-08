import Synchronization

/// A Bool a `@Sendable` closure raises and a test reads: such a closure can
/// neither capture a mutable local nor be trusted to run on one thread.
final class AtomicFlag: Sendable {
  private let value = Atomic(false)

  init() {}

  var raised: Bool { value.load(ordering: .acquiring) }
  func raise() { value.store(true, ordering: .releasing) }
}
