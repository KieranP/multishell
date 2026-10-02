import Synchronization

/// One waiting continuation, resumed by whichever caller settles it first.
/// A class, as a bare `Mutex` captured by escaping closures does not compile on every toolchain.
final class ContinuationSlot<Value: Sendable>: Sendable {
  private let waiting = Mutex<CheckedContinuation<Value, Never>?>(nil)

  func hold(_ continuation: CheckedContinuation<Value, Never>) {
    waiting.withLock { $0 = continuation }
  }

  /// Later calls find nothing to resume.
  func settle(_ value: Value) {
    waiting.withLock { $0.take() }?.resume(returning: value)
  }
}
