import MultishellCore

/// What a strip says, kept out of the views so the wording is tested.
extension DebugMetric {
  public var title: String {
    switch self {
    case .frameRate: t("debug.metric.frame-rate")
    case .cpu: t("debug.metric.cpu")
    case .gitRuns: t("debug.metric.git-runs")
    case .stateReports: t("debug.metric.state-reports")
    case .memory: t("debug.metric.memory")
    }
  }

  /// The slot's value as the strip's label reads it, none before a sample.
  public func valueText(of slot: DebugTimelineSlot?) -> String {
    guard let slot else { return DebugValueText.noValue }
    return switch self {
    case .frameRate:
      slot.framesPerSecond.map(DebugValueText.framesPerSecond) ?? DebugValueText.noValue
    case .cpu: DebugValueText.percent(slot.totalCPUPercent)
    case .gitRuns: DebugValueText.perSecond(slot.gitRunsStartedPerSecond)
    case .stateReports: DebugValueText.perSecond(slot.stateReportsPerSecond)
    case .memory: DebugValueText.memory(slot.totalMemory)
    }
  }

  /// What colours the value: frame rate alone, by how smooth the slot was.
  public func valueSmoothness(of slot: DebugTimelineSlot?) -> Smoothness? {
    self == .frameRate ? slot?.smoothness : nil
  }

  /// A second line under the value: each owner's share where the strip splits,
  /// the runs still going for git, else nothing.
  public func detailText(of slot: DebugTimelineSlot) -> String? {
    switch self {
    case .cpu:
      t(
        "debug.split", DebugValueText.percent(slot.appCPUPercent),
        DebugValueText.percent(slot.childrenCPUPercent))
    case .memory:
      t(
        "debug.split-memory", DebugValueText.memory(slot.appMemoryOutsideTerminals),
        DebugValueText.memory(slot.terminalMemory), DebugValueText.memory(slot.childrenMemory))
    case .gitRuns where slot.gitRunningCount > 0:
      t("count.git-running", slot.gitRunningCount)
    case .frameRate, .gitRuns, .stateReports:
      nil
    }
  }
}
