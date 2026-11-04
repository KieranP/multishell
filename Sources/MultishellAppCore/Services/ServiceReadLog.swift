import Foundation

/// When each project's services, or each worktree's panel reads, were last
/// asked and which are being asked, so the poll asks each at its interval.
struct ServiceReadLog<Key: Hashable & Sendable>: Sendable {
  private var lastAsked: [Key: ContinuousClock.Instant] = [:]
  private var asking: Set<Key> = []
  /// By the waiter's own token, so a cancelled wait is ended alone.
  private var endWaiters: [Key: [UUID: CheckedContinuation<Void, Never>]] = [:]

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

  /// Whether it was asked since it last went due; a move of its upstreams
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
    resumeEndWaiters(of: id)
  }

  /// Resumed once the read of `id` under way ends, at once where none is.
  mutating func awaitEnd(
    of id: Key,
    as token: UUID,
    _ waiter: CheckedContinuation<Void, Never>,
  ) {
    guard asking.contains(id) else {
      waiter.resume()
      return
    }
    endWaiters[id, default: [:]][token] = waiter
  }

  /// The wait `token` names resumed now, its asker gone; ended already, nothing.
  mutating func endWait(_ token: UUID, of id: Key) {
    endWaiters[id]?.removeValue(forKey: token)?.resume()
  }

  /// Due at once, however recent the last read: what it read has moved.
  mutating func markDue(_ id: Key) {
    lastAsked[id] = nil
  }

  mutating func forget(_ id: Key) {
    lastAsked[id] = nil
    asking.remove(id)
    resumeEndWaiters(of: id)
  }

  private mutating func resumeEndWaiters(of id: Key) {
    for waiter in endWaiters.removeValue(forKey: id)?.values ?? [:].values { waiter.resume() }
  }

  mutating func forget(where isGone: (Key) -> Bool) {
    lastAsked = lastAsked.filter { !isGone($0.key) }
    for id in asking where isGone(id) { resumeEndWaiters(of: id) }
    asking = asking.filter { !isGone($0) }
  }
}
