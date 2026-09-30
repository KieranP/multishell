import Foundation
import Synchronization

/// Whether a directory exists, answered off the main actor within a bound: a
/// dead mount costs the window the bound, not the mount's timeout.
final class DirectoryProbe: Sendable {
  enum Answer: Equatable {
    case present
    case missing
    case unanswered
  }

  private let bound: DispatchTimeInterval
  private let exists: @Sendable (String) -> Bool
  private let inFlight = Mutex<Set<String>>([])

  init(
    bound: DispatchTimeInterval = .seconds(1),
    exists: @escaping @Sendable (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
  ) {
    self.bound = bound
    self.exists = exists
  }

  func probe(_ path: String) -> Answer {
    // A stat still in flight on this path would only be joined by another thread.
    guard inFlight.withLock({ $0.insert(path).inserted }) else { return .unanswered }
    let pending = PendingProbe()
    DispatchQueue.global(qos: .userInteractive).async { [self] in
      let found = exists(path)
      inFlight.withLock { _ = $0.remove(path) }
      pending.settle(found)
    }
    return pending.wait(for: bound).map { $0 ? .present : .missing } ?? .unanswered
  }
}
