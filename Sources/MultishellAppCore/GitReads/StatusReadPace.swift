/// How often a worktree's `git status` may be read: never twice within the
/// minimum gap, and a slow read holds the next back ten times what it cost.
struct StatusReadPace: Sendable {
  static let standard = Self(minimumGap: .seconds(1), costMultiple: 10)
  /// Every worktree on every ask, for a test that reads right after a change.
  static let unpaced = Self(minimumGap: .zero, costMultiple: 0)

  /// File events arrive in bursts while a build or a dev server writes, and
  /// each would otherwise spawn git.
  let minimumGap: Duration
  /// The disk spends at most one part in this many on a worktree's status.
  private let costMultiple: Int

  init(minimumGap: Duration, costMultiple: Int) {
    self.minimumGap = minimumGap
    self.costMultiple = costMultiple
  }

  /// Nil for a worktree never read, which is due now.
  func nextDue(
    lastRead: ContinuousClock.Instant?,
    duration: Duration?,
  ) -> ContinuousClock.Instant? {
    guard let lastRead else { return nil }
    return lastRead + max(minimumGap, (duration ?? .zero) * costMultiple)
  }

  func isDue(
    lastRead: ContinuousClock.Instant?,
    duration: Duration?,
    at now: ContinuousClock.Instant,
  ) -> Bool {
    nextDue(lastRead: lastRead, duration: duration).map { now >= $0 } ?? true
  }
}
