import Foundation

/// How often a worktree's `git status` is asked for: every tick, unless the
/// last read cost more than a tenth of the interval; see worktrees.md.
public struct StatusPollPace: Sendable {
  /// How long the frontmost app waits between rounds of status reads.
  public var interval: Duration
  /// The disk spends at most one part in this many on a worktree's status.
  public var dutyCycle: Int

  public static let standard = StatusPollPace(interval: .seconds(5), dutyCycle: 10)
  /// Every worktree every tick, for a test that reads right after a change.
  public static let unpaced = StatusPollPace(interval: .seconds(5), dutyCycle: 0)

  public init(interval: Duration, dutyCycle: Int) {
    self.interval = interval
    self.dutyCycle = dutyCycle
  }

  public func isDue(
    lastRead: ContinuousClock.Instant?, took: Duration?, at now: ContinuousClock.Instant
  ) -> Bool {
    guard let lastRead, let took, took * dutyCycle > interval else { return true }
    return lastRead.duration(to: now) >= took * dutyCycle
  }
}
