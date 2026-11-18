import Foundation
import MultishellProcess

/// One `DebugSample` as `multishell debug samples` prints it: plain numbers,
/// durations in milliseconds and memory in bytes.
struct DebugSampleRecord: Encodable, Equatable {
  struct CLIExecutionRecord: Encodable, Equatable {
    let runs: Int
    let totalMilliseconds: Double
    let slowestMilliseconds: Double
    let peakMemory: UInt64?
  }

  struct WorkRecord: Encodable, Equatable {
    let count: Int
    let totalMilliseconds: Double
    let slowestMilliseconds: Double
    let bytesWritten: UInt64

    init(_ tally: DebugWorkTally) {
      count = tally.count
      totalMilliseconds = tally.totalDuration.inMilliseconds
      slowestMilliseconds = tally.slowestDuration.inMilliseconds
      bytesWritten = tally.bytesWritten
    }
  }

  let sequence: Int
  let takenAt: Date
  let elapsedMilliseconds: Double
  /// Absent where the display sent no frame, asleep rather than stalled.
  let framesPerSecond: Double?
  let longestFrameMilliseconds: Double?
  let cliExecutionsStarted: Int
  let cliExecutionsRunning: Int
  let cliExecutions: [String: CLIExecutionRecord]
  let appCPUPercent: Double
  let childrenCPUPercent: Double
  let appMemory: UInt64
  let terminalMemory: UInt64
  let childrenMemory: UInt64
  let stateReports: Int
  let stateReportHandling: WorkRecord
  let stateSaves: WorkRecord
  let marks: [String]
  let mainThreadCPUPercent: Double
  let terminalThreadsCPUPercent: Double
  let diskBytesRead: UInt64
  let diskBytesWritten: UInt64
  let interruptWakeups: UInt64
  let packageIdleWakeups: UInt64
  let peakMemory: UInt64
  let threads: Int
  /// Absent where the kernel would not say.
  let openDescriptors: Int?
  let memoryPressure: String?
  let fileEvents: Int

  init(_ sample: DebugSample) {
    sequence = sample.sequence
    takenAt = sample.takenAt
    elapsedMilliseconds = sample.elapsed.inMilliseconds
    framesPerSecond = sample.frameRate?.framesPerSecond
    longestFrameMilliseconds = sample.frameRate.map(\.longestFrame.inMilliseconds)
    cliExecutionsStarted = sample.cliExecutionsStartedCount
    cliExecutionsRunning = sample.cliExecutionsRunningCount
    cliExecutions = sample.cliExecutions.mapValues { tally in
      CLIExecutionRecord(
        runs: tally.runCount,
        totalMilliseconds: tally.totalDuration.inMilliseconds,
        slowestMilliseconds: tally.slowestDuration.inMilliseconds,
        peakMemory: tally.peakMemory,
      )
    }
    appCPUPercent = sample.appCPUPercent
    childrenCPUPercent = sample.childrenCPUPercent
    appMemory = sample.appMemory
    terminalMemory = sample.terminalMemory
    childrenMemory = sample.childrenMemory
    stateReports = sample.stateReportCount
    stateReportHandling = WorkRecord(sample.stateReports)
    stateSaves = WorkRecord(sample.stateSaves)
    marks = sample.marks
    mainThreadCPUPercent = sample.threadCPU.mainPercent
    terminalThreadsCPUPercent = sample.threadCPU.terminalsPercent
    diskBytesRead = sample.activity.diskBytesRead
    diskBytesWritten = sample.activity.diskBytesWritten
    interruptWakeups = sample.activity.interruptWakeups
    packageIdleWakeups = sample.activity.packageIdleWakeups
    peakMemory = sample.peakMemory
    threads = sample.threadCount
    openDescriptors = sample.openDescriptorCount
    memoryPressure = sample.memoryPressure.map { String(describing: $0) }
    fileEvents = sample.fileEventCount
  }
}
