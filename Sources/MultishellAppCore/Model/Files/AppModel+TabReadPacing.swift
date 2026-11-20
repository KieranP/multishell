/// The wait before a file tab's or the All changes tab's read, which a burst
/// of saves and the last read's cost set; see Docs/design/files/file-tabs.md.
extension AppModel {
  /// A burst of saves becomes one read: 0.15 s of FSEvents latency, then this.
  private static var readSettleDelay: Duration { .milliseconds(75) }

  /// `read` after the settle and once `nextDue` allows, or `atOnce`; the model
  /// is not held while it waits.
  func pacedTabRead(
    atOnce: Bool,
    nextDue: @escaping @MainActor (AppModel) -> ContinuousClock.Instant?,
    read: @escaping @MainActor (AppModel) async -> Void,
  ) -> Task<Void, Never> {
    Task { @MainActor [weak self] in
      if !atOnce { try? await Task.sleep(for: Self.readSettleDelay) }
      while !atOnce, !Task.isCancelled, let due = self.flatMap(nextDue), due > .now {
        try? await Task.sleep(until: due)
      }
      guard !Task.isCancelled, let self else { return }
      await read(self)
    }
  }
}
