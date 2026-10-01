import Synchronization

extension Task where Failure == Never {
  /// The task's value if it ends within `limit`, else `nil`. It runs on either
  /// way: a git read cancelled midway would never land its answer.
  func value(within limit: Duration) async -> Success? {
    let waitingCaller = Mutex<CheckedContinuation<Success?, Never>?>(nil)
    @Sendable func settle(_ value: Success?) {
      waitingCaller.withLock { $0.take() }?.resume(returning: value)
    }
    return await withCheckedContinuation { continuation in
      waitingCaller.withLock { $0 = continuation }
      let timeout = Task<Void, Never> {
        try? await Task<Never, Never>.sleep(for: limit)
        settle(nil)
      }
      Task<Void, Never> {
        settle(await self.value)
        timeout.cancel()
      }
    }
  }
}
