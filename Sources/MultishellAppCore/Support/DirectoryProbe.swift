import Foundation

/// Whether a directory exists, answered off the main actor within a bound: a
/// dead mount costs the window the bound, not the mount's timeout.
final class DirectoryProbe: @unchecked Sendable {
  enum Answer: Equatable {
    case present
    case missing
    case unanswered
  }

  private let bound: DispatchTimeInterval
  private let exists: @Sendable (String) -> Bool
  private let lock = NSLock()
  private var stuck: Set<String> = []

  init(
    bound: DispatchTimeInterval = .seconds(1),
    exists: @escaping @Sendable (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
  ) {
    self.bound = bound
    self.exists = exists
  }

  func probe(_ path: String) -> Answer {
    // A stat still stuck on this path would only be joined by another thread.
    guard lock.withLock({ stuck.insert(path).inserted }) else { return .unanswered }
    let answer = ProbeAnswer()
    DispatchQueue.global(qos: .userInteractive).async { [self] in
      let found = exists(path)
      lock.withLock { _ = stuck.remove(path) }
      answer.settle(found)
    }
    return answer.wait(for: bound).map { $0 ? .present : .missing } ?? .unanswered
  }
}

private final class ProbeAnswer: @unchecked Sendable {
  private let lock = NSLock()
  private let done = DispatchSemaphore(value: 0)
  private var found: Bool?

  func settle(_ value: Bool) {
    lock.withLock { found = value }
    done.signal()
  }

  func wait(for bound: DispatchTimeInterval) -> Bool? {
    guard done.wait(timeout: .now() + bound) == .success else { return nil }
    return lock.withLock { found }
  }
}
