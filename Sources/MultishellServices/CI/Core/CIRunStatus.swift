/// Where a CI run, or one of its workflows or jobs, stands. Raw values are
/// what `worktrees show` prints.
public enum CIRunStatus: String, Hashable, Sendable {
  /// Stopped before it finished, or never run.
  case cancelled
  /// Something in it failed or errored, or the service rejected its config.
  /// Said as soon as one job fails, though others may still be running.
  case failed
  /// Waiting on someone to approve a job.
  case onHold = "on-hold"
  case passed
  /// Queued or under way.
  case running

  /// Whether a check or job with this status may still change by itself,
  /// which reads it again sooner; a whole run's is `CIRun.isUnderWay`.
  public var isUnderWay: Bool { self == .running }
}
