import MultishellCore

/// What a git row says in its memory cells, and where the table is too narrow
/// for its columns.
extension DebugGitCommand {
  public var meanPeakMemoryText: String {
    tally.meanPeakMemory.map(DebugValueText.memory) ?? DebugValueText.noValue
  }

  public var peakMemoryText: String {
    tally.peakMemory.map(DebugValueText.memory) ?? DebugValueText.noValue
  }

  /// Runs, mean and slowest time, and where the slowest ran.
  public var timingSummary: String {
    let timing = t(
      "debug.git-summary", t("count.runs", tally.runCount),
      DebugValueText.duration(tally.meanDuration),
      DebugValueText.duration(tally.slowestDuration))
    guard let slowestLocation else { return timing }
    return t("debug.git-summary-in", timing, slowestLocation.title)
  }

  /// `nil` where no run's peak memory was read.
  public var memorySummary: String? {
    guard let mean = tally.meanPeakMemory, let peak = tally.peakMemory else { return nil }
    return t(
      "debug.git-memory-summary", DebugValueText.memory(mean), DebugValueText.memory(peak))
  }
}
