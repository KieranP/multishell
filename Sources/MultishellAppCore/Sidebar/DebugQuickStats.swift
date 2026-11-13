/// The sidebar's three cells: the last sample's frame rate, CPU and memory,
/// and the last minute of each as a sparkline, each point a fraction of its height.
public struct DebugQuickStats: Sendable, Equatable {
  let framesPerSecond: Int?
  public let smoothness: Smoothness
  /// The app and every child process, as Activity Monitor adds them up.
  let totalCPUPercent: Double?
  let totalMemory: UInt64?
  /// `nil` for a frameless second, a display asleep rather than a drop to zero,
  /// kept as a gap so each point lines up with the same second's CPU.
  public let frameRateTrend: [Double?]
  public let cpuTrend: [Double]
  /// Between the minute's lowest and highest rather than from zero: a few
  /// hundred megabytes on two gigabytes is otherwise a flat line.
  public let memoryTrend: [Double]

  init(history: DebugHistory) {
    let latest = history.latest
    let recent = history.samples(in: .oneMinute)
    framesPerSecond = latest?.frameRate.map { Int($0.framesPerSecond.rounded()) }
    smoothness = latest?.smoothness ?? .smooth
    totalCPUPercent = latest?.totalCPUPercent
    totalMemory = latest?.totalMemory
    let framesPerSecond = recent.map(\.frameRate?.framesPerSecond)
    let frameRateScale = DebugMetric.frameRate.scale(
      forPeak: framesPerSecond.compactMap(\.self).max() ?? 0
    )
    frameRateTrend = framesPerSecond.map { rate in rate.map { min($0 / frameRateScale, 1) } }
    cpuTrend = Self.fractionsOfScale(recent.map(\.totalCPUPercent), scaledAs: .cpu)
    memoryTrend = Self.fractionsBetweenExtremes(recent.map { Double($0.totalMemory) })
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
