/// How often a worktree's `git status` is asked for: every tick, unless the
/// last read cost more than a tenth of the interval; see worktrees.md.
struct StatusPollPace: Sendable {
  /// How long the frontmost app waits between rounds of status reads.
  var interval: Duration
  /// The disk spends at most one part in this many on a worktree's status.
  var costMultiple: Int

  static let standard = StatusPollPace(interval: .seconds(5), costMultiple: 10)
  /// Every worktree every tick, for a test that reads right after a change.
  static let unpaced = StatusPollPace(interval: .seconds(5), costMultiple: 0)

  init(interval: Duration, costMultiple: Int) {
    self.interval = interval
    self.costMultiple = costMultiple
  }

  func isDue(
    lastRead: ContinuousClock.Instant?, took: Duration?, at now: ContinuousClock.Instant
  ) -> Bool {
    guard let lastRead, let took, took * costMultiple > interval else { return true }
    return lastRead.duration(to: now) >= took * costMultiple
  }
}
