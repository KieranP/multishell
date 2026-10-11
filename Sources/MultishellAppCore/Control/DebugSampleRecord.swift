import Foundation
import MultishellProcess

/// One `DebugSample` as `multishell debug samples` prints it: plain numbers,
/// durations in milliseconds and memory in bytes.
struct DebugSampleRecord: Encodable, Equatable {
  struct GitCommandRecord: Encodable, Equatable {
    let runs: Int
    let totalMilliseconds: Double
    let slowestMilliseconds: Double
    let peakMemory: UInt64?
  }

  let sequence: Int
  let takenAt: Date
  let elapsedMilliseconds: Double
  /// Absent where the display sent no frame, asleep rather than stalled.
  let framesPerSecond: Double?
  let longestFrameMilliseconds: Double?
  let gitRunsStarted: Int
  let gitRunning: Int
  let gitCommands: [String: GitCommandRecord]
  let appCPUPercent: Double
  let childrenCPUPercent: Double
  let appMemory: UInt64
  let terminalMemory: UInt64
  let childrenMemory: UInt64
  let stateReports: Int
  let marks: [String]

  init(_ sample: DebugSample) {
    sequence = sample.sequence
    takenAt = sample.takenAt
    elapsedMilliseconds = sample.elapsed.inMilliseconds
    framesPerSecond = sample.frameRate?.framesPerSecond
    longestFrameMilliseconds = sample.frameRate.map(\.longestFrame.inMilliseconds)
    gitRunsStarted = sample.gitRunsStartedCount
    gitRunning = sample.gitRunningCount
    gitCommands = sample.gitCommands.mapValues { tally in
      GitCommandRecord(
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
    marks = sample.marks
  }
}
