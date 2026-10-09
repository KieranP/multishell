import MultishellCore

/// What a git row says in its cells, and where the table is too narrow for
/// its columns.
extension DebugGitCommand {
  public var runCountText: String { "\(tally.runCount)" }

  public var totalDurationText: String { DebugValueText.duration(tally.totalDuration) }

  public var meanDurationText: String { DebugValueText.duration(tally.meanDuration) }

  public var slowestDurationText: String { DebugValueText.duration(tally.slowestDuration) }

  /// Empty where no run was placed in a worktree.
  public var slowestLocationText: String { slowestLocation?.title ?? "" }

  public var meanPeakMemoryText: String {
    tally.meanPeakMemory.map(DebugValueText.memory) ?? DebugValueText.noValue
  }

  public var peakMemoryText: String {
    tally.peakMemory.map(DebugValueText.memory) ?? DebugValueText.noValue
  }

  /// Runs, mean and slowest time, and where the slowest ran.
  var timingSummary: String {
    let timing = t(
      "debug.git-summary",
      t("count.runs", tally.runCount),
      meanDurationText,
      slowestDurationText,
    )
    guard let slowestLocation else { return timing }
    return t("debug.git-summary-in", timing, slowestLocation.title)
  }

  /// `nil` where no run's peak memory was read.
  var memorySummary: String? {
    guard let mean = tally.meanPeakMemory, let peak = tally.peakMemory else { return nil }
    return t(
      "debug.git-memory-summary",
      DebugValueText.memory(mean),
      DebugValueText.memory(peak),
    )
  }

  /// The lines under the command where the panel is too narrow for columns.
  public var stackedCaptions: [String] {
    [timingSummary] + [memorySummary].compactMap(\.self)
  }
}
