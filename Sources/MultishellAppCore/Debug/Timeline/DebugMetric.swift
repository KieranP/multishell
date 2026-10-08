/// A strip on Debug Info, in the order the panel draws them.
public enum DebugMetric: CaseIterable, Sendable {
  case frameRate
  case cpu
  case gitRuns
  case stateReports
  case memory

  /// Drawn as the app under everything it started, in two colours, or three
  /// where it `showsTerminals`.
  public var isSplitByOwner: Bool { self == .cpu || self == .memory }

  /// Memory alone: the terminals hold memory in the app's process, but their
  /// CPU is the app's own threads, which the kernel does not split.
  public var showsTerminals: Bool { self == .memory }

  /// A count per second, drawn as bars; the rest are levels, drawn as areas.
  public var drawsBars: Bool { self == .gitRuns || self == .stateReports }

  /// The app's own part, that with its terminals, and the whole, or `nil`
  /// where the slot has no reading.
  func values(
    of slot: DebugTimelineSlot
  ) -> (app: Double, appWithTerminals: Double, total: Double)? {
    let unsplit = { (value: Double) in (value, value, value) }
    return switch self {
    case .frameRate: slot.framesPerSecond.map(unsplit)
    case .cpu: (slot.appCPUPercent, slot.appCPUPercent, slot.totalCPUPercent)
    case .gitRuns: unsplit(slot.gitRunsStartedPerSecond)
    case .stateReports: unsplit(slot.stateReportsPerSecond)
    case .memory:
      (
        Double(slot.appMemoryOutsideTerminals), Double(slot.appMemory),
        Double(slot.totalMemory)
      )
    }
  }

  /// The top of the strip for a peak, never so low that a quiet second fills
  /// it: a frame rate in whole 60s, one core, ten git runs, five reports.
  func scale(forPeak peak: Double) -> Double {
    switch self {
    case .frameRate: max(60, (peak / 60).rounded(.up) * 60)
    case .cpu: max(100, peak)
    case .gitRuns: max(10, peak)
    case .stateReports: max(5, peak)
    case .memory: max(1, peak * 1.1)
    }
  }
}
