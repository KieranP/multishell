import Synchronization

/// A `@Sendable` counter, `isStopped` being called from a closure that
/// cannot capture a mutable local.
final class CallCounter: Sendable {
  private let value = Atomic(0)

  func next() -> Int {
    value.wrappingAdd(1, ordering: .relaxed).oldValue
  }
}
