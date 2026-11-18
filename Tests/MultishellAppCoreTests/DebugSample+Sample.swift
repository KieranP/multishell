import Foundation

@testable import MultishellAppCore
@testable import MultishellProcess

extension DebugSample {
  static func sample(
    sequence: Int,
    framesPerSecond: Double? = 120,
    longestFrame: Duration = .milliseconds(9),
    cliExecutionsStartedCount: Int = 0,
    cliExecutionsRunningCount: Int = 0,
    cliExecutions: [String: CLIExecutionTally] = [:],
    appCPUPercent: Double = 0,
    childrenCPUPercent: Double = 0,
    appMemory: UInt64 = 400,
    terminalMemory: UInt64 = 0,
    childrenMemory: UInt64 = 1_000,
    stateReportCount: Int = 0,
    mainThreadCPUPercent: Double = 0,
    terminalThreadsCPUPercent: Double = 0,
    activity: DebugActivityCounts = .zero,
    memoryPressure: MemoryPressureLevel? = nil,
    peakMemory: UInt64 = 0,
    threadCount: Int = 0,
    openDescriptorCount: Int? = nil,
    fileEventCount: Int = 0,
    elapsed: Duration = .seconds(1),
  ) -> DebugSample {
    var sample = DebugSample(
      sequence: sequence,
      takenAt: Date(timeIntervalSince1970: Double(sequence)),
      elapsed: elapsed,
      frameRate: framesPerSecond.map { frames in
        FrameRateReading(framesPerSecond: frames, longestFrame: longestFrame)
      },
      cliExecutionsStartedCount: cliExecutionsStartedCount,
      cliExecutionsRunningCount: cliExecutionsRunningCount,
      cliExecutions: cliExecutions,
      appCPUPercent: appCPUPercent,
      childrenCPUPercent: childrenCPUPercent,
      appMemory: appMemory,
      terminalMemory: terminalMemory,
      childrenMemory: childrenMemory,
      stateReports: .counting(stateReportCount),
    )
    sample.threadCPU = DebugThreadCPU(
      mainPercent: mainThreadCPUPercent,
      terminalsPercent: terminalThreadsCPUPercent,
      byThread: [:],
    )
    sample.activity = activity
    sample.memoryPressure = memoryPressure
    sample.peakMemory = peakMemory
    sample.threadCount = threadCount
    sample.openDescriptorCount = openDescriptorCount
    sample.fileEventCount = fileEventCount
    return sample
  }
}
