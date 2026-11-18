import Foundation
import MultishellProcess

/// What `debug samples --summary` prints: each reading's least, mean and most,
/// a mean over the time the samples covered (debug-tools.md).
struct DebugSummaryRecord: Encodable, Equatable {
  struct Spread: Encodable, Equatable {
    let least: Double
    let mean: Double
    let most: Double

    /// `nil` for no readings. Each is weighed by the seconds it covered, which
    /// `DebugSample.elapsedSeconds` keeps above zero.
    init?(_ readings: [(value: Double, seconds: Double)]) {
      let values = readings.map(\.value)
      guard let least = values.min(), let most = values.max() else { return nil }
      self.least = least
      self.most = most
      mean =
        readings.reduce(0) { $0 + $1.value * $1.seconds } / readings.reduce(0) { $0 + $1.seconds }
    }
  }

  struct Mark: Encodable, Equatable {
    let sample: Int
    let name: String
  }

  let sampleCount: Int
  let firstSample: Int?
  let lastSample: Int?
  let seconds: Double
  /// `nil` where the display sent no frame in any of them.
  let framesPerSecond: Spread?
  let longestFrameMilliseconds: Spread?
  let appCPUPercent: Spread?
  let childrenCPUPercent: Spread?
  let appMemory: Spread?
  let terminalMemory: Spread?
  let childrenMemory: Spread?
  let mainThreadCPUPercent: Spread?
  let terminalThreadsCPUPercent: Spread?
  let diskBytesReadPerSecond: Spread?
  let diskBytesWrittenPerSecond: Spread?
  let interruptWakeupsPerSecond: Spread?
  let packageIdleWakeupsPerSecond: Spread?
  let threads: Spread?
  /// `nil` where the kernel never said.
  let openDescriptors: Spread?
  let peakMemory: UInt64?
  /// The worst any sample saw.
  let memoryPressure: String?
  let cliExecutionsStarted: Int
  let stateReports: Int
  let stateReportHandling: DebugSampleRecord.WorkRecord
  let stateSaves: DebugSampleRecord.WorkRecord
  let fileEvents: Int
  let marks: [Mark]

  init(_ samples: ArraySlice<DebugSample>) {
    func spread(_ reading: (DebugSample) -> Double?) -> Spread? {
      Spread(samples.compactMap { sample in reading(sample).map { ($0, sample.elapsedSeconds) } })
    }
    sampleCount = samples.count
    firstSample = samples.first?.sequence
    lastSample = samples.last?.sequence
    seconds = samples.reduce(0) { $0 + $1.elapsedSeconds }
    framesPerSecond = spread { $0.frameRate?.framesPerSecond }
    longestFrameMilliseconds = spread { $0.frameRate.map(\.longestFrame.inMilliseconds) }
    appCPUPercent = spread(\.appCPUPercent)
    childrenCPUPercent = spread(\.childrenCPUPercent)
    appMemory = spread { Double($0.appMemory) }
    terminalMemory = spread { Double($0.terminalMemory) }
    childrenMemory = spread { Double($0.childrenMemory) }
    func perSecond(_ count: @escaping (DebugSample) -> UInt64) -> Spread? {
      spread { Double(count($0)) / $0.elapsedSeconds }
    }
    mainThreadCPUPercent = spread(\.threadCPU.mainPercent)
    terminalThreadsCPUPercent = spread(\.threadCPU.terminalsPercent)
    diskBytesReadPerSecond = perSecond(\.activity.diskBytesRead)
    diskBytesWrittenPerSecond = perSecond(\.activity.diskBytesWritten)
    interruptWakeupsPerSecond = perSecond(\.activity.interruptWakeups)
    packageIdleWakeupsPerSecond = perSecond(\.activity.packageIdleWakeups)
    threads = spread { Double($0.threadCount) }
    openDescriptors = spread { $0.openDescriptorCount.map(Double.init) }
    peakMemory = samples.map(\.peakMemory).max()
    memoryPressure = samples.compactMap(\.memoryPressure).max().map { String(describing: $0) }
    cliExecutionsStarted = samples.reduce(0) { $0 + $1.cliExecutionsStartedCount }
    stateReports = samples.reduce(0) { $0 + $1.stateReportCount }
    stateReportHandling = DebugSampleRecord.WorkRecord(
      samples.reduce(into: DebugWorkTally.empty) { $0.merge($1.stateReports) }
    )
    stateSaves = DebugSampleRecord.WorkRecord(
      samples.reduce(into: DebugWorkTally.empty) { $0.merge($1.stateSaves) }
    )
    fileEvents = samples.reduce(0) { $0 + $1.fileEventCount }
    marks = samples.flatMap { sample in
      sample.marks.map { Mark(sample: sample.sequence, name: $0) }
    }
  }
}
