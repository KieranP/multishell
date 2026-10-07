/// A strip on the debug panel, in the order the panel draws them.
public enum DebugMetric: CaseIterable, Sendable {
  case frameRate
  case cpu
  case gitRuns
  case stateReports
  case memory

  /// Drawn as the app under everything it started, in two colours.
  public var isSplitByOwner: Bool { self == .cpu || self == .memory }

  /// A count per second, drawn as bars; the rest are levels, drawn as areas.
  public var drawsBars: Bool { self == .gitRuns || self == .stateReports }

  /// The app's part and the whole, or `nil` where the slot has no reading.
  func values(of slot: DebugTimelineSlot) -> (app: Double, total: Double)? {
    switch self {
    case .frameRate: slot.framesPerSecond.map { ($0, $0) }
    case .cpu: (slot.appCPUPercent, slot.totalCPUPercent)
    case .gitRuns: (slot.gitRunsStartedPerSecond, slot.gitRunsStartedPerSecond)
    case .stateReports: (slot.stateReportsPerSecond, slot.stateReportsPerSecond)
    case .memory: (Double(slot.appMemory), Double(slot.totalMemory))
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
