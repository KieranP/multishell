import MultishellCore
import MultishellProcess

/// What a tile says, kept out of the views so the wording is tested.
extension DebugMetric {
  public var title: String {
    switch self {
    case .frameRate: t("debug.metric.frame-rate")
    case .cpu: t("debug.metric.cpu")
    case .memory: t("debug.metric.memory")
    case .memoryPressure: t("debug.metric.memory-pressure")
    case .wakeups: t("debug.metric.wakeups")
    case .disk: t("debug.metric.disk")
    case .stateReports: t("debug.metric.state-reports")
    case .cliActivity: t("debug.metric.cli-activity")
    case .fileEvents: t("debug.metric.file-events")
    case .threads: t("debug.metric.threads")
    case .openFiles: t("debug.metric.open-files")
    case .peakMemory: t("debug.metric.peak-memory")
    }
  }

  /// The slot's value as the tile's label reads it, none before a sample.
  public func valueText(of slot: DebugTimelineSlot?) -> String {
    guard let slot else { return DebugValueText.noValue }
    return switch self {
    case .frameRate:
      slot.framesPerSecond.map(DebugValueText.framesPerSecond) ?? DebugValueText.noValue

    case .cpu: DebugValueText.percent(slot.totalCPUPercent)
    case .memory: DebugValueText.memory(slot.totalMemory)
    case .memoryPressure: slot.memoryPressure.map(\.title) ?? DebugValueText.noValue

    case .wakeups: DebugValueText.perSecond(slot.interruptWakeupsPerSecond)

    case .disk:
      DebugValueText.bytesPerSecond(slot.diskBytesReadPerSecond + slot.diskBytesWrittenPerSecond)

    case .stateReports: DebugValueText.perSecond(slot.stateReportsPerSecond)
    case .cliActivity: DebugValueText.perSecond(slot.cliExecutionsStartedPerSecond)
    case .fileEvents: DebugValueText.perSecond(slot.fileEventsPerSecond)
    case .threads: String(slot.threadCount)
    case .openFiles: slot.openDescriptorCount.map(String.init) ?? DebugValueText.noValue
    case .peakMemory: DebugValueText.memory(slot.peakMemory)
    }
  }

  /// A line under the value: each band's share where the tile splits, what
  /// a figure counts where its name alone does not say, else nothing.
  public func detailText(of slot: DebugTimelineSlot) -> String? {
    switch self {
    case .cpu:
      t(
        "debug.split-cpu",
        DebugValueText.percent(slot.mainThreadCPUPercent),
        DebugValueText.percent(slot.terminalThreadsCPUPercent),
        DebugValueText.percent(slot.otherThreadsCPUPercent),
        DebugValueText.percent(slot.childrenCPUPercent),
      )

    case .memory:
      t(
        "debug.split-memory",
        DebugValueText.memory(slot.appMemoryOutsideTerminals),
        DebugValueText.memory(slot.terminalMemoryWithinApp),
        DebugValueText.memory(slot.childrenMemory),
      )

    case .memoryPressure: t("debug.memory-pressure-detail")

    case .wakeups:
      t(
        "debug.split-wakeups",
        DebugValueText.perSecond(slot.interruptWakeupsPerSecond),
        DebugValueText.perSecond(slot.packageIdleWakeupsPerSecond),
      )

    case .disk:
      t(
        "debug.split-disk",
        DebugValueText.bytesPerSecond(slot.diskBytesReadPerSecond),
        DebugValueText.bytesPerSecond(slot.diskBytesWrittenPerSecond),
      )

    case .stateReports where !slot.stateReports.isEmpty:
      t(
        "debug.reports-handled",
        DebugValueText.duration(slot.stateReports.meanDuration),
        DebugValueText.duration(slot.stateReports.slowestDuration),
      )

    case .cliActivity where slot.cliExecutionsRunningCount > 0:
      t("count.cli-executions-running", slot.cliExecutionsRunningCount)

    case .fileEvents: t("debug.file-events-detail")
    case .openFiles: t("debug.open-files-detail")
    case .peakMemory: t("debug.peak-memory-detail")

    case .frameRate, .stateReports, .cliActivity, .threads:
      nil
    }
  }
}
