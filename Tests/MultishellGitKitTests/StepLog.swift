import Synchronization

/// Collects the steps an operation reports, from whatever thread they arrive on.
final class StepLog<Step: Sendable>: Sendable {
  private let collected = Mutex<[Step]>([])

  var steps: [Step] { collected.withLock { $0 } }
  func add(_ step: Step) { collected.withLock { $0.append(step) } }
  func clear() { collected.withLock { $0 = [] } }
}
