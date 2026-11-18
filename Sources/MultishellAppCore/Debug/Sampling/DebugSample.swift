import Foundation
import MultishellProcess

/// One sample of what Debug Info charts, a second's worth unless a
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
  let cliExecutionsStartedCount: Int
  /// Still going at the sample, which a git hung on a dead mount stays.
  let cliExecutionsRunningCount: Int
  let cliExecutions: [String: CLIExecutionTally]
  let appCPUPercent: Double
  /// Everything the app started, panes and git alike.
  let childrenCPUPercent: Double
  /// The app's whole footprint, its panes' terminals included.
  let appMemory: UInt64
  /// What the panes' terminals held, part of `appMemory`.
  let terminalMemory: UInt64
  let childrenMemory: UInt64
  /// Each report the socket brought, timed as the main actor handled it.
  let stateReports: DebugWorkTally
  /// What `multishell debug mark` named in this second, oldest first.
  var marks: [String] = []
  var threadCPU = DebugThreadCPU.unmeasured
  var activity = DebugActivityCounts.zero
  /// The largest footprint since launch, which macOS keeps for the process.
  var peakMemory: UInt64 = 0
  var threadCount = 0
  /// Files, pipes and sockets; `nil` where the kernel would not say.
  var openDescriptorCount: Int?
  var memoryPressure: MemoryPressureLevel?
  var stateSaves = DebugWorkTally.empty
  var fileEventCount = 0

  var stateReportCount: Int { stateReports.count }

  var totalMemory: UInt64 { appMemory + childrenMemory }
  var totalCPUPercent: Double { appCPUPercent + childrenCPUPercent }
  var smoothness: Smoothness { .of(longestFrame: frameRate?.longestFrame) }

  /// Never zero: the meters' readings are a clock tick apart at the least.
  var elapsedSeconds: Double { max(elapsed.inSeconds, 0.001) }
}
