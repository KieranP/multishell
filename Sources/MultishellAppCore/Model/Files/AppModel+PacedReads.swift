import MultishellCore

/// The Files panel's reads a busy disk would repeat back to back: one per key
/// at a time, the next waiting on its cost and the listing rebuild it set off.
extension AppModel {
  /// Ten times what the last read and rebuild cost, so a build's churn takes
  /// about a tenth of a core.
  private static var readCostMultiple: Int { 10 }

  func schedulePacedRead<Key: Hashable, Value: Sendable>(
    _ key: Key,
    in id: Worktree.ID,
    on reads: ReferenceWritableKeyPath<AppModel, CoalescedReads<Key>>,
    reading: @escaping @Sendable () async -> Value,
    landing: @escaping @MainActor (AppModel, Value) -> Void,
    rerun: @escaping @MainActor (AppModel) -> Void,
  ) {
    self[keyPath: reads].start(key) {
      Task { @MainActor [weak self] in
        let started = ContinuousClock.now
        let value = await reading()
        let cost = started.duration(to: .now)
        if let self, !Task.isCancelled, workspace.worktree(id) != nil { landing(self, value) }
        guard let pause = self?.pause(afterReadCosting: cost, in: id) else { return }
        try? await Task.sleep(for: pause)
        guard let self, !Task.isCancelled, self[keyPath: reads].finish(key) else { return }
        rerun(self)
      }
    }
  }

  private func pause(afterReadCosting cost: Duration, in id: Worktree.ID) -> Duration {
    let rebuildCost =
      fileTreeListings[id]?.buildCost ?? fileTreeCache[id]?.tree.listing.buildCost ?? .zero
    return max(.seconds(1), (cost + rebuildCost) * Self.readCostMultiple)
  }
}
