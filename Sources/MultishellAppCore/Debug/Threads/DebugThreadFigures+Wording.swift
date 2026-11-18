import MultishellCore

/// What a CPU Breakdown row says in its cells, and where the table is too
/// narrow for its columns.
extension DebugThreadFigures {
  public var threadCountText: String { String(threadCount) }

  public var meanPercentText: String { DebugValueText.percent(meanPercent) }

  public var cpuTimeText: String { DebugValueText.duration(cpuTime) }

  /// The lines under the name where the panel is too narrow for columns.
  public var stackedCaptions: [String] {
    [t("debug.thread-summary", t("count.threads", threadCount), meanPercentText)]
  }
}
