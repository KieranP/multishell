import Synchronization

/// Counts the calls the code under test makes of a `@Sendable` closure, which
/// cannot capture a mutable local.
final class CallCounter: Sendable {
  private let value = Atomic(0)

  func next() -> Int {
    value.wrappingAdd(1, ordering: .relaxed).oldValue
  }
}
