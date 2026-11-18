import Foundation
import MultishellCore

/// What the next debug sample is measured from, and the tick that takes it.
struct DebugSampler {
  var ticks: Task<Void, Never>?
  /// Settable so a test can push the tick out of reach and take each sample itself.
  var interval: Duration = .seconds(1)
  var frameRateMeter = FrameRateMeter()
  var cpuUsageMeter = CPUUsageMeter()
  var threadCPUMeter = ThreadCPUMeter()
  var activityMeter = ProcessActivityMeter()
  /// The reports handled on the main actor since the last sample, and how long each took.
  var stateReports = DebugWorkTally.empty
  var stateSaves = DebugWorkTally.empty
  /// Directories the file watcher reported changed since the last sample.
  var fileEventCount = 0
  /// Read on the main actor at the start, so the scan can tell which thread is main.
  var mainThreadID: UInt64 = 0
  /// Names `multishell debug mark` gave since the last sample.
  var pendingMarks: [String] = []
  var lastSampleAt: ContinuousClock.Instant?
  /// Bumped at each start and stop, so a sample begun before either lands nowhere.
  var generation = 0
  /// Reads the kernel's process table; a test stands in a scan of its own.
  var scanProcesses:
    @Sendable (
      _ appPID: Int32,
      _ terminalPaths: [TerminalSession.ID: String],
      _ mainThreadID: UInt64,
    ) -> DebugProcessScan = DebugProcessScan.take

  /// Every reading starts from `now`: no frame or report from before counts.
  mutating func start(at now: ContinuousClock.Instant) {
    generation += 1
    clearReadings()
    lastSampleAt = now
    _ = frameRateMeter.takeReading(at: now)
  }

  mutating func stop() {
    generation += 1
    ticks?.cancel()
    ticks = nil
    clearReadings()
  }

  private mutating func clearReadings() {
    frameRateMeter = FrameRateMeter()
    cpuUsageMeter = CPUUsageMeter()
    threadCPUMeter = ThreadCPUMeter()
    activityMeter = ProcessActivityMeter()
    lastSampleAt = nil
    stateReports = .empty
    stateSaves = .empty
    fileEventCount = 0
    pendingMarks = []
  }
}
