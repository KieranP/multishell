import Foundation

/// A stat blocking like one on a dead mount until released, or ten seconds on,
/// so a model that waited fails rather than hangs the suite.
final class HangingStat: @unchecked Sendable {
  private let lock = NSLock()
  private let gate = DispatchSemaphore(value: 0)
  private var callCount = 0
  private var returned = false

  init() {
    DispatchQueue.global().asyncAfter(deadline: .now() + 10) { [gate] in gate.signal() }
  }

  var calls: Int { lock.withLock { callCount } }
  var hasReturned: Bool { lock.withLock { returned } }

  var exists: @Sendable (String) -> Bool {
    { [self] _ in
      lock.withLock { callCount += 1 }
      gate.wait()
      lock.withLock { returned = true }
      return true
    }
  }

  func release() { gate.signal() }
}
