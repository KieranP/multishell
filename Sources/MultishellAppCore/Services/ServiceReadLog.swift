/// When each project's services, or each worktree's panel reads, were last
/// asked and which are being asked, so the poll asks each at its interval.
struct ServiceReadLog<Key: Hashable & Sendable>: Sendable {
  private var lastAsked: [Key: ContinuousClock.Instant] = [:]
  private var asking: Set<Key> = []

  /// Never asked is due; `interval` is the poll's, `activation` a return's.
  func isDue(
    _ id: Key,
    at now: ContinuousClock.Instant,
    interval: Duration = ServiceReadInterval.poll,
  ) -> Bool {
    guard !asking.contains(id) else { return false }
    guard let last = lastAsked[id] else { return true }
    return now - last >= interval
  }

  func isAsking(_ id: Key) -> Bool { asking.contains(id) }

  /// Whether it was ever asked, which a move of its upstreams
  /// before then has no answer of its own to correct.
  func hasAsked(_ id: Key) -> Bool { lastAsked[id] != nil }

  /// `false` where it is already being asked, which that read answers.
  mutating func begin(_ id: Key, at now: ContinuousClock.Instant) -> Bool {
    guard asking.insert(id).inserted else { return false }
    lastAsked[id] = now
    return true
  }

  mutating func finish(_ id: Key) {
    asking.remove(id)
  }

  /// Due at once, however recent the last read: what it read has moved.
  mutating func markDue(_ id: Key) {
    lastAsked[id] = nil
  }

  mutating func forget(_ id: Key) {
    lastAsked[id] = nil
    asking.remove(id)
  }

  mutating func forget(where isGone: (Key) -> Bool) {
    lastAsked = lastAsked.filter { !isGone($0.key) }
    asking = asking.filter { !isGone($0) }
  }
}
