import Foundation
import MultishellCore
import MultishellGitKit
import MultishellProcess

extension AppModel {
  /// Every reading starts from now: no frame or report from before counts,
  /// and the first second's CPU reads 0, having nothing to measure from.
  func startDebugSampling() {
    debugSampler.start(at: .now)
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
    debugHistory = DebugHistory()
    debugProcessAttribution = .empty
    debugTerminalMemoryBySession = [:]
    pausedDebugSnapshot = nil
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
    let generation = debugSampler.generation
    let scan = await runOnDispatch { scanProcesses(appPID, terminalPaths) }
    guard generation == debugSampler.generation else { return }

    let now = ContinuousClock.now
    let elapsed = debugSampler.lastSampleAt.map { $0.duration(to: now) } ?? .seconds(1)
    debugSampler.lastSampleAt = now
    let children = scan.childProcesses
    let gitActivity = coordinator?.git.runLog.drain() ?? .empty
    let cpu = debugSampler.cpuUsageMeter.takeReading(
      of: (scan.app.map { [$0] } ?? []) + children,
      at: now,
      exited: gitActivity.finishedRuns.compactMap(\.exitUsage).map { ($0.pid, $0.cpuTime) },
    )
    let cpuPercentByPID = cpu.byPID
    debugHistory.append(
      DebugSample(
        sequence: debugHistory.nextSequence,
        takenAt: Date(),
        elapsed: elapsed,
        frameRate: debugSampler.frameRateMeter.takeReading(at: now),
        gitRunsStartedCount: gitActivity.startedCount,
        gitRunningCount: gitActivity.runningCount,
        gitCommands: GitCommandTally.byCommand(gitActivity.finishedRuns),
        appCPUPercent: scan.app.flatMap { cpuPercentByPID[$0.pid] } ?? 0,
        childrenCPUPercent: children.reduce(cpu.exitedPercent) { total, child in
          total + (cpuPercentByPID[child.pid] ?? 0)
        },
        appMemory: scan.app?.footprint ?? 0,
        terminalMemory: terminalMemoryBySession.values.reduce(0, +),
        childrenMemory: children.totalMemory,
        stateReportCount: debugSampler.stateReportCount,
      )
    )
    debugSampler.stateReportCount = 0
    debugProcessAttribution = PaneProcessAttribution(
      trees: scan.trees,
      terminalDevices: scan.terminalDevices,
      foregroundPIDs: hints.compactMapValues(\.foregroundPID),
    )
    debugTerminalMemoryBySession = terminalMemoryBySession
  }
}
