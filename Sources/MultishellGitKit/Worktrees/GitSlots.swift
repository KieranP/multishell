import Foundation

/// At most `width` holders at once, the rest queued in arrival order. Shared
/// by every copy of the service, so projects read together share one width.
final class GitSlots: @unchecked Sendable {
  private let lock = NSLock()
  private var free: Int
  private var waiting: [CheckedContinuation<Void, Never>] = []

  init(width: Int) {
    free = width
  }

  func holding<T: Sendable>(_ work: @Sendable () async -> T) async -> T {
    await acquire()
    defer { release() }
    return await work()
  }

  private func acquire() async {
    await withCheckedContinuation { continuation in
      let admitted = lock.withLock {
        guard free > 0 else {
          waiting.append(continuation)
          return false
        }
        free -= 1
        return true
      }
      if admitted { continuation.resume() }
    }
  }

  /// A slot freed goes straight to the next waiter, never back to the pool.
  private func release() {
    let next = lock.withLock { () -> CheckedContinuation<Void, Never>? in
      guard !waiting.isEmpty else {
        free += 1
        return nil
      }
      return waiting.removeFirst()
    }
    next?.resume()
  }
}
