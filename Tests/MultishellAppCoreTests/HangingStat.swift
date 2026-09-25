import Foundation
import Synchronization

/// A stat blocking like one on a dead mount until released, or ten seconds on,
/// so a model that waited fails rather than hangs the suite.
final class HangingStat: Sendable {
  private let gate = DispatchSemaphore(value: 0)
  private let state = Mutex<(calls: Int, returned: Bool)>((0, false))

  init() {
    DispatchQueue.global().asyncAfter(deadline: .now() + 10) { [gate] in gate.signal() }
  }

  var calls: Int { state.withLock { $0.calls } }
  var hasReturned: Bool { state.withLock { $0.returned } }

  var exists: @Sendable (String) -> Bool {
    { [self] _ in
      state.withLock { $0.calls += 1 }
      gate.wait()
      state.withLock { $0.returned = true }
      return true
    }
  }

  func release() { gate.signal() }
}
