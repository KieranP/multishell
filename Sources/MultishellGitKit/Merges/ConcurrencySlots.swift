import Synchronization

/// At most `width` holders at once, the rest queued in arrival order.
final class ConcurrencySlots: Sendable {
  private let slots: Mutex<(free: Int, waiting: [CheckedContinuation<Void, Never>])>

  init(width: Int) {
    slots = Mutex((width, []))
  }

  func holding<T: Sendable>(_ work: @Sendable () async -> T) async -> T {
    await acquire()
    defer { release() }
    return await work()
  }

  private func acquire() async {
    await withCheckedContinuation { continuation in
      let admitted = slots.withLock { slots in
        guard slots.free > 0 else {
          slots.waiting.append(continuation)
          return false
        }
        slots.free -= 1
        return true
      }
      if admitted { continuation.resume() }
    }
  }

  /// A slot freed goes straight to the next waiter, never back to the pool.
  private func release() {
    let next = slots.withLock { slots -> CheckedContinuation<Void, Never>? in
      guard !slots.waiting.isEmpty else {
        slots.free += 1
        return nil
      }
      return slots.waiting.removeFirst()
    }
    next?.resume()
  }
}
