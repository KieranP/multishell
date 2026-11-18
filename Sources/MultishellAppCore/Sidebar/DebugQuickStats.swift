/// The sidebar's three cells: the last sample's CPU, memory and disk, and
/// the last minute of each as a sparkline, each point a fraction of its height.
public struct DebugQuickStats: Sendable, Equatable {
  /// The app and every child process, as Activity Monitor adds them up.
  let totalCPUPercent: Double?
  let totalMemory: UInt64?
  /// What the app read and wrote over the last sample, per second.
  let diskBytesPerSecond: Double?
  public let cpuTrend: [Double]
  /// Between the minute's lowest and highest rather than from zero: a few
  /// hundred megabytes on two gigabytes is otherwise a flat line.
  public let memoryTrend: [Double]
  public let diskTrend: [Double]

  init(history: DebugHistory) {
    let latest = history.latest
    let recent = history.samples(in: .oneMinute)
    totalCPUPercent = latest?.totalCPUPercent
    totalMemory = latest?.totalMemory
    diskBytesPerSecond = latest.map(Self.diskBytesPerSecond)
    cpuTrend = Self.fractionsOfScale(recent.map(\.totalCPUPercent), scaledAs: .cpu)
    memoryTrend = Self.fractionsBetweenExtremes(recent.map { Double($0.totalMemory) })
    diskTrend = Self.fractionsOfScale(recent.map(Self.diskBytesPerSecond), scaledAs: .disk)
  }

  private static func diskBytesPerSecond(of sample: DebugSample) -> Double {
    Double(sample.activity.diskBytesRead + sample.activity.diskBytesWritten)
      / sample.elapsedSeconds
  }

  private static func fractionsOfScale(
    _ values: [Double],
    scaledAs metric: DebugMetric,
  ) -> [Double] {
    let scale = metric.scale(forPeak: values.max() ?? 0)
    return values.map { min($0 / scale, 1) }
  }

  private static func fractionsBetweenExtremes(_ values: [Double]) -> [Double] {
    guard let lowest = values.min(), let highest = values.max(), highest > lowest else {
      return values.map { _ in 0.5 }
    }
    return values.map { ($0 - lowest) / (highest - lowest) }
  }
}
