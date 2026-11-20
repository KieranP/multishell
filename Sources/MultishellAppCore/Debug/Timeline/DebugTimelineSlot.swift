import Foundation
import MultishellProcess

/// The seconds one point of a chart stands for, combined the way each chart
/// reads them: the worst frame, the mean rate, the latest memory.
public struct DebugTimelineSlot: Sendable, Equatable {
  let startedAt: Date
  /// The slowest second's, so a dip shows at every range.
  let framesPerSecond: Double?
  let longestFrame: Duration?
  let cliExecutionsStartedPerSecond: Double
  let cliExecutionsRunningCount: Int
  let appCPUPercent: Double
  let childrenCPUPercent: Double
  let appMemory: UInt64
  let terminalMemory: UInt64
  let childrenMemory: UInt64
  let stateReportsPerSecond: Double
  /// Every report's handling added up, for the mean and the slowest.
  let stateReports: DebugWorkTally
  let mainThreadCPUPercent: Double
  let terminalThreadsCPUPercent: Double
  let diskBytesReadPerSecond: Double
  let diskBytesWrittenPerSecond: Double
  let interruptWakeupsPerSecond: Double
  let packageIdleWakeupsPerSecond: Double
  /// The worst any second reached, so a brief warning shows at every range.
  let memoryPressure: MemoryPressureLevel?
  let peakMemory: UInt64
  let threadCount: Int
  let openDescriptorCount: Int?
  let fileEventsPerSecond: Double

  public var smoothness: Smoothness { .of(longestFrame: longestFrame) }
  var totalCPUPercent: Double { appCPUPercent + childrenCPUPercent }
  var totalMemory: UInt64 { appMemory + childrenMemory }
  /// What the main thread and the terminals leave of the app's CPU: threads
  /// that came and went between readings land here too.
  var otherThreadsCPUPercent: Double {
    max(appCPUPercent - mainThreadCPUPercent - terminalThreadsCPUPercent, 0)
  }
  /// Never below zero: Ghostty's figure for a terminal is an estimate.
  var appMemoryOutsideTerminals: UInt64 { appMemory.subtractingFlooredAtZero(terminalMemory) }
  var terminalMemoryWithinApp: UInt64 { appMemory - appMemoryOutsideTerminals }

  /// `samples` is never empty: a slot no sample landed in is not made.
  init(samples: [DebugSample]) {
    // Over the time covered, not per sample: one a stall held four seconds
    // holds four seconds of runs and of CPU.
    let seconds = samples.map(\.elapsedSeconds).reduce(0, +)
    func timeWeightedMean(_ percent: (DebugSample) -> Double) -> Double {
      samples.map { percent($0) * $0.elapsedSeconds }.reduce(0, +) / seconds
    }
    func perSecond(_ count: (DebugSample) -> UInt64) -> Double {
      Double(samples.reduce(0) { $0 + count($1) }) / seconds
    }
    let frameRates = samples.compactMap(\.frameRate)
    startedAt = samples.first?.takenAt ?? .distantPast
    framesPerSecond = frameRates.map(\.framesPerSecond).min()
    longestFrame = frameRates.map(\.longestFrame).max()
    cliExecutionsStartedPerSecond =
      Double(samples.map(\.cliExecutionsStartedCount).reduce(0, +)) / seconds
    cliExecutionsRunningCount = samples.last?.cliExecutionsRunningCount ?? 0
    appCPUPercent = timeWeightedMean(\.appCPUPercent)
    childrenCPUPercent = timeWeightedMean(\.childrenCPUPercent)
    appMemory = samples.last?.appMemory ?? 0
    terminalMemory = samples.last?.terminalMemory ?? 0
    childrenMemory = samples.last?.childrenMemory ?? 0
    stateReportsPerSecond = Double(samples.map(\.stateReportCount).reduce(0, +)) / seconds
    stateReports = samples.reduce(into: DebugWorkTally.empty) { $0.merge($1.stateReports) }
    mainThreadCPUPercent = timeWeightedMean(\.threadCPU.mainPercent)
    terminalThreadsCPUPercent = timeWeightedMean(\.threadCPU.terminalsPercent)
    diskBytesReadPerSecond = perSecond(\.activity.diskBytesRead)
    diskBytesWrittenPerSecond = perSecond(\.activity.diskBytesWritten)
    interruptWakeupsPerSecond = perSecond(\.activity.interruptWakeups)
    packageIdleWakeupsPerSecond = perSecond(\.activity.packageIdleWakeups)
    memoryPressure = samples.compactMap(\.memoryPressure).max()
    peakMemory = samples.last?.peakMemory ?? 0
    threadCount = samples.last?.threadCount ?? 0
    openDescriptorCount = samples.last?.openDescriptorCount
    fileEventsPerSecond = perSecond { UInt64($0.fileEventCount) }
  }
}
