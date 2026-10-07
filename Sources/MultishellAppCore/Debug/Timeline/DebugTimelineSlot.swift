import Foundation

/// The seconds one point of a strip stands for, combined the way each chart
/// reads them: the worst frame, the mean rate, the latest memory.
public struct DebugTimelineSlot: Sendable, Equatable {
  public let startedAt: Date
  /// The slowest second's, so a dip shows at every range.
  let framesPerSecond: Double?
  let longestFrame: Duration?
  let gitRunsStartedPerSecond: Double
  let gitRunningCount: Int
  let appCPUPercent: Double
  let childrenCPUPercent: Double
  let appMemory: UInt64
  let childrenMemory: UInt64
  let stateReportsPerSecond: Double

  /// `samples` is never empty: a slot no sample landed in is not made.
  init(samples: [DebugSample]) {
    // Over the time covered, not per sample: one a stall held four seconds
    // holds four seconds of runs and of CPU.
    let seconds = samples.map(\.elapsedSeconds).reduce(0, +)
    func timeWeightedMean(_ percent: (DebugSample) -> Double) -> Double {
      samples.map { percent($0) * $0.elapsedSeconds }.reduce(0, +) / seconds
    }
    let frameRates = samples.compactMap(\.frameRate)
    startedAt = samples.first?.takenAt ?? .distantPast
    framesPerSecond = frameRates.map(\.framesPerSecond).min()
    longestFrame = frameRates.map(\.longestFrame).max()
    gitRunsStartedPerSecond = Double(samples.map(\.gitRunsStartedCount).reduce(0, +)) / seconds
    gitRunningCount = samples.last?.gitRunningCount ?? 0
    appCPUPercent = timeWeightedMean(\.appCPUPercent)
    childrenCPUPercent = timeWeightedMean(\.childrenCPUPercent)
    appMemory = samples.last?.appMemory ?? 0
    childrenMemory = samples.last?.childrenMemory ?? 0
    stateReportsPerSecond = Double(samples.map(\.stateReportCount).reduce(0, +)) / seconds
  }

  public var smoothness: Smoothness { .of(longestFrame: longestFrame) }
  var totalCPUPercent: Double { appCPUPercent + childrenCPUPercent }
  var totalMemory: UInt64 { appMemory + childrenMemory }
}
