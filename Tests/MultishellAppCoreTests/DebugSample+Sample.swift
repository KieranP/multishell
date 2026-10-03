import Foundation

@testable import MultishellAppCore

extension DebugSample {
  static func sample(
    sequence: Int, framesPerSecond: Double? = 120, longestFrame: Duration = .milliseconds(9),
    gitRunsStartedCount: Int = 0, gitRunningCount: Int = 0,
    gitCommands: [String: GitCommandTally] = [:],
    appCPUPercent: Double = 0, childrenCPUPercent: Double = 0,
    appMemory: UInt64 = 400, childrenMemory: UInt64 = 1_000, stateReportCount: Int = 0,
    elapsed: Duration = .seconds(1)
  ) -> DebugSample {
    DebugSample(
      sequence: sequence, takenAt: Date(timeIntervalSince1970: Double(sequence)),
      elapsed: elapsed,
      frameRate: framesPerSecond.map {
        FrameRateReading(framesPerSecond: $0, longestFrame: longestFrame)
      },
      gitRunsStartedCount: gitRunsStartedCount, gitRunningCount: gitRunningCount,
      gitCommands: gitCommands,
      appCPUPercent: appCPUPercent, childrenCPUPercent: childrenCPUPercent, appMemory: appMemory,
      childrenMemory: childrenMemory, stateReportCount: stateReportCount)
  }
}
