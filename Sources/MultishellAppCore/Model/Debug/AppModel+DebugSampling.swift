import Foundation
import MultishellCore
import MultishellGitKit
import MultishellProcess

extension AppModel {
  /// Every reading starts from now: no frame or report from before counts,
  /// and the first second's CPU reads 0, having nothing to measure from.
  func startDebugSampling() {
    debugSampler.start(at: .now)
    debugSampler.mainThreadID = ThreadUsage.currentThreadID()
    platform.startDisplayFrameCallbacks { [weak self] instant in
      self?.debugSampler.frameRateMeter.noteFrame(at: instant)
    }
    debugSampler.ticks = Task { [weak self] in
      while !Task.isCancelled {
        guard let interval = self?.debugSampler.interval else { return }
        try? await Task.sleep(for: interval)
        guard !Task.isCancelled else { return }
        await self?.takeDebugSample()
      }
    }
  }

  func stopDebugSamplingAndClear() {
    debugSampler.stop()
    platform.stopDisplayFrameCallbacks()
    debugHistory = DebugHistory(numberingFrom: debugHistory.nextSequence)
    debugGitRuns = DebugGitRunLog()
    debugProcessAttribution = .empty
    debugTerminalMemoryBySession = [:]
    debugAppMemoryParts = nil
    pausedDebugSnapshot = nil
    pausedDebugMemoryTable = nil
  }

  /// One second's frames, git runs and reports, and the process table read
  /// off the main actor, each pane's processes placed by what the engine says.
  func takeDebugSample() async {
    guard areDebugToolsEnabled else { return }
    var hints: [TerminalSession.ID: TerminalProcessHint] = [:]
    var terminalMemoryBySession: [TerminalSession.ID: UInt64] = [:]
    for id in liveSessionIDs {
      hints[id] = host.processHint(of: id)
      terminalMemoryBySession[id] = host.terminalMemory(of: id)
    }
    let terminalPaths = hints.compactMapValues(\.terminalPath)
    let appPID = ProcessInfo.processInfo.processIdentifier
    let scanProcesses = debugSampler.scanProcesses
    let mainThreadID = debugSampler.mainThreadID
    let generation = debugSampler.generation
    // Timed where the CPU was read: after the await, a stall begun mid-scan
    // stretched one second's share over its length and squeezed the next's.
    let (scan, scannedAt) = await runOnDispatch {
      (scanProcesses(appPID, terminalPaths, mainThreadID), ContinuousClock.now)
    }
    guard generation == debugSampler.generation else { return }

    let now = ContinuousClock.now
    let elapsed = debugSampler.lastSampleAt.map { $0.duration(to: now) } ?? .seconds(1)
    debugSampler.lastSampleAt = now
    let children = scan.childProcesses
    let gitActivity = coordinator?.git.runLog.drain() ?? .empty
    let cpu = debugSampler.cpuUsageMeter.takeReading(
      of: (scan.app.map { [$0] } ?? []) + children,
      at: scannedAt,
      exited: gitActivity.finishedRuns.compactMap(\.exitUsage).map { ($0.pid, $0.cpuTime) },
    )
    let cpuPercentByPID = cpu.byPID
    let sequence = debugHistory.nextSequence
    debugGitRuns.append(gitActivity.finishedRuns, inSample: sequence)
    var sample = DebugSample(
      sequence: sequence,
      takenAt: Date(),
      elapsed: elapsed,
      frameRate: debugSampler.frameRateMeter.takeReading(at: now),
      cliExecutionsStartedCount: gitActivity.startedCount,
      cliExecutionsRunningCount: gitActivity.runningCount,
      cliExecutions: CLIExecutionTally.byCommand(gitActivity.finishedRuns),
      appCPUPercent: scan.app.flatMap { cpuPercentByPID[$0.pid] } ?? 0,
      childrenCPUPercent: children.reduce(cpu.exitedPercent) { total, child in
        total + (cpuPercentByPID[child.pid] ?? 0)
      },
      appMemory: scan.app?.footprint ?? 0,
      terminalMemory: terminalMemoryBySession.values.reduce(0, +),
      childrenMemory: children.totalMemory,
      stateReports: debugSampler.stateReports,
      marks: debugSampler.pendingMarks,
    )
    noteOwnReadings(of: scan, at: scannedAt, in: &sample)
    debugHistory.append(sample)
    debugSampler.stateReports = .empty
    debugSampler.pendingMarks = []
    debugProcessAttribution = PaneProcessAttribution(
      trees: scan.trees,
      terminalDevices: scan.terminalDevices,
      foregroundPIDs: hints.compactMapValues(\.foregroundPID),
    )
    debugTerminalMemoryBySession = terminalMemoryBySession
    debugAppMemoryParts = scan.appParts
  }

  /// What the app read of itself, and the saves and file events counted
  /// since the last sample, whose counts start again.
  private func noteOwnReadings(
    of scan: DebugProcessScan,
    at scannedAt: ContinuousClock.Instant,
    in sample: inout DebugSample,
  ) {
    sample.threadCPU = debugSampler.threadCPUMeter.takeReading(of: scan.threads, at: scannedAt)
    sample.activity = debugSampler.activityMeter.takeReading(of: scan.appActivity)
    sample.peakMemory = scan.appActivity?.peakFootprint ?? 0
    sample.threadCount = scan.threads.count
    sample.openDescriptorCount = scan.openDescriptorCount
    sample.memoryPressure = scan.memoryPressure
    sample.stateSaves = debugSampler.stateSaves
    sample.fileEventCount = debugSampler.fileEventCount
    debugSampler.stateSaves = .empty
    debugSampler.fileEventCount = 0
  }
}
