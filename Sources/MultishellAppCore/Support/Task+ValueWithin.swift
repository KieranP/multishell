extension Task where Failure == Never {
  /// The task's value if it ends within `limit`, else `nil`. It runs on either
  /// way: a git read cancelled midway would never land its answer.
  func value(within limit: Duration) async -> Success? {
    let caller = ContinuationSlot<Success?>()
    return await withCheckedContinuation { continuation in
      caller.hold(continuation)
      let timeout = Task<Void, Never> {
        try? await Task<Never, Never>.sleep(for: limit)
        caller.settle(nil)
      }
      Task<Void, Never> {
        caller.settle(await self.value)
        timeout.cancel()
      }
    }
  }
}
