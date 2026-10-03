import Foundation
import MultishellProcess

/// One sample of what the debug panel charts, a second's worth unless a
/// stall held it longer.
struct DebugSample: Sendable, Equatable {
  /// Counts up from the first sample, so a slot of several seconds holds the
  /// same ones every time it is drawn.
  let sequence: Int
  let takenAt: Date
  /// Since the sample before: a second, or longer where a stall held it.
  let elapsed: Duration
  /// `nil` where the display sent no frame: asleep, not stalled.
  let frameRate: FrameRateReading?
  let gitRunsStartedCount: Int
  /// Still going at the sample, which a git hung on a dead mount stays.
  let gitRunningCount: Int
  let gitCommands: [String: GitCommandTally]
  let appCPUPercent: Double
  /// Everything the app started, panes and git alike.
  let childrenCPUPercent: Double
  let appMemory: UInt64
  let childrenMemory: UInt64
  let stateReportCount: Int

  var totalMemory: UInt64 { appMemory + childrenMemory }
  var totalCPUPercent: Double { appCPUPercent + childrenCPUPercent }
  var smoothness: Smoothness { .of(longestFrame: frameRate?.longestFrame) }

  /// Never zero: the meters' readings are a clock tick apart at the least.
  var elapsedSeconds: Double { max(elapsed.inSeconds, 0.001) }
}
