import MultishellProcess

// Declared order is the order allCases gives the UI: most telling of a
// slow app first (debug-tools.md).
// swiftlint:disable sorted_enum_cases
/// A tile on Debug Info, in the order the panel draws them.
public enum DebugMetric: CaseIterable, Sendable {
  case frameRate
  case cpu
  case memory
  case memoryPressure
  case wakeups
  case disk
  case stateReports
  case cliActivity
  case fileEvents
  case threads
  case openFiles
  case peakMemory

  /// The bands a split tile stacks, bottom to top; empty for one series.
  public var series: [DebugSeries] {
    switch self {
    case .cpu: [.mainThread, .terminalThreads, .otherThreads, .childProcesses]
    case .memory: [.app, .appTerminals, .childProcesses]
    case .wakeups: [.packageIdleWakeups, .otherInterruptWakeups]
    case .disk: [.diskRead, .diskWritten]

    case .frameRate, .memoryPressure, .stateReports, .cliActivity, .fileEvents, .threads,
      .openFiles,
      .peakMemory:
      []
    }
  }

  /// A count per second, drawn as bars; the rest are levels, drawn as areas.
  public var drawsBars: Bool {
    self == .cliActivity || self == .stateReports || self == .fileEvents
  }

  /// One value per series, bottom to top, or the one value of an unsplit
  /// tile; `nil` where the slot has no reading.
  func values(of slot: DebugTimelineSlot) -> [Double]? {
    switch self {
    case .frameRate: slot.framesPerSecond.map { [$0] }

    case .cpu:
      [
        slot.mainThreadCPUPercent, slot.terminalThreadsCPUPercent, slot.otherThreadsCPUPercent,
        slot.childrenCPUPercent,
      ]

    case .memory:
      [
        Double(slot.appMemoryOutsideTerminals),
        Double(slot.terminalMemoryWithinApp),
        Double(slot.childrenMemory),
      ]

    case .memoryPressure: slot.memoryPressure.map { [Double($0.rawValue + 1)] }

    case .wakeups:
      [
        slot.packageIdleWakeupsPerSecond,
        max(slot.interruptWakeupsPerSecond - slot.packageIdleWakeupsPerSecond, 0),
      ]

    case .disk: [slot.diskBytesReadPerSecond, slot.diskBytesWrittenPerSecond]
    case .stateReports: [slot.stateReportsPerSecond]
    case .cliActivity: [slot.cliExecutionsStartedPerSecond]
    case .fileEvents: [slot.fileEventsPerSecond]
    case .threads: [Double(slot.threadCount)]
    case .openFiles: slot.openDescriptorCount.map { [Double($0)] }
    case .peakMemory: [Double(slot.peakMemory)]
    }
  }

  /// What colours the value: the frame rate by how smooth the slot was, the
  /// pressure by its level; the rest read plain.
  public func valueTone(of slot: DebugTimelineSlot?) -> DebugValueTone? {
    switch self {
    case .frameRate: slot.map { DebugValueTone($0.smoothness) }
    case .memoryPressure: slot?.memoryPressure.map(DebugValueTone.init)

    case .cpu, .memory, .wakeups, .disk, .stateReports, .cliActivity, .fileEvents, .threads,
      .openFiles, .peakMemory:
      nil
    }
  }

  /// The top of the tile's chart for a peak, never so low that a quiet second
  /// fills it: a frame rate in whole 60s, one core, ten executions, five reports.
  func scale(forPeak peak: Double) -> Double {
    switch self {
    case .frameRate: max(60, (peak / 60).rounded(.up) * 60)
    case .cpu: max(100, peak)
    case .memoryPressure: Double(MemoryPressureLevel.critical.rawValue + 1)
    case .wakeups, .cliActivity: max(10, peak)
    case .stateReports, .fileEvents: max(5, peak)
    case .disk: max(64 * 1_024, peak * 1.1)
    case .memory, .threads, .openFiles, .peakMemory: max(1, peak * 1.1)
    }
  }
}
// swiftlint:enable sorted_enum_cases
