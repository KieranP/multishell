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
  private let stuck = Mutex<Set<String>>([])

  init(
    bound: DispatchTimeInterval = .seconds(1),
    exists: @escaping @Sendable (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
  ) {
    self.bound = bound
    self.exists = exists
  }

  func probe(_ path: String) -> Answer {
    // A stat still stuck on this path would only be joined by another thread.
    guard stuck.withLock({ $0.insert(path).inserted }) else { return .unanswered }
    let answer = ProbeAnswer()
    DispatchQueue.global(qos: .userInteractive).async { [self] in
      let found = exists(path)
      stuck.withLock { _ = $0.remove(path) }
      answer.settle(found)
    }
    return answer.wait(for: bound).map { $0 ? .present : .missing } ?? .unanswered
  }
}

private final class ProbeAnswer: Sendable {
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
