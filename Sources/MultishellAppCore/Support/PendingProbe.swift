import Foundation
import Synchronization

final class PendingProbe: Sendable {
  private let done = DispatchSemaphore(value: 0)
  private let found = Mutex<Bool?>(nil)

  func settle(_ value: Bool) {
    found.withLock { $0 = value }
    done.signal()
  }

  func wait(for bound: DispatchTimeInterval) -> Bool? {
    guard done.wait(timeout: .now() + bound) == .success else { return nil }
    return found.withLock { $0 }
  }
}
