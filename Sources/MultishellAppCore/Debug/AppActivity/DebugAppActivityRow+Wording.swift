import MultishellCore

/// What an App Activity row says in its cells, and where the table is too
/// narrow for its columns.
extension DebugAppActivityRow {
  public var title: String {
    switch kind {
    case .stateReports: t("debug.app-activity.state-reports")
    case .stateSaves: t("debug.app-activity.state-saves")
    }
  }

  public var countText: String { String(tally.count) }

  public var totalDurationText: String { DebugValueText.duration(tally.totalDuration) }

  public var meanDurationText: String { DebugValueText.duration(tally.meanDuration) }

  public var slowestDurationText: String { DebugValueText.duration(tally.slowestDuration) }

  /// The dash for work that writes nothing.
  public var bytesWrittenText: String {
    bytesWritten.map(DebugValueText.memory) ?? DebugValueText.noValue
  }

  /// The lines under the name where the panel is too narrow for columns.
  public var stackedCaptions: [String] {
    let timing = t(
      "debug.app-activity-summary",
      t("count.times", tally.count),
      meanDurationText,
      slowestDurationText,
    )
    guard bytesWritten != nil else { return [timing] }
    return [timing, t("debug.written", bytesWrittenText)]
  }
}
