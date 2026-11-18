import Foundation
import MultishellCore
import MultishellGitKit
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellProcess

@Suite @MainActor
struct AppModelDebugSamplingTests {
  @Test func aSampleAddsUpTheAppAndEveryChildAndTheReportsSinceTheLast() async throws {
    let harness = Harness()
    harness.model.enableDebugTools(
      scan: .sample(appMemory: 400, trees: [(10, [10, 11]), (20, [20])])
    )
    harness.model.receive(SessionStateReport(state: .running))
    harness.model.receive(SessionStateReport(state: .idle))

    await harness.model.takeDebugSample()
    await harness.model.takeDebugSample()

    let samples = harness.model.debugHistory.samples
    #expect(samples.map(\.stateReportCount) == [2, 0])
    let latest = try #require(samples.last)
    #expect(latest.appMemory == 400)
    #expect(latest.childrenMemory == 300)
    #expect(samples.map(\.sequence) == [0, 1])
  }

  @Test func aSampleAddsUpWhatEveryPanesTerminalHeld() async throws {
    let (harness, session) = Harness.withOnePane()
    harness.model.newTab()
    let second = try #require(harness.model.workspace.tabs.last).focusedSessionID
    harness.engine.terminalMemories[session.id] = 150
    harness.engine.terminalMemories[second] = 50
    harness.model.enableDebugTools()

    await harness.model.takeDebugSample()

    #expect(harness.model.debugHistory.latest?.terminalMemory == 200)
  }

  @Test func aGitRunThatStartsAndEndsBetweenTwoSamplesCountsInTheChildrensCPU() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let model = harness.model
    let git = try #require(model.coordinator?.git)
    let worktree = try #require(model.workspace.worktrees.first)
    model.enableDebugTools()
    await model.takeDebugSample()

    _ = await git.isRepository(worktree.path)
    await model.takeDebugSample()

    #expect((model.debugHistory.latest?.childrenCPUPercent ?? 0) > 0)
  }

  @Test func aSampleCarriesTheScansThreadsActivityDescriptorsAndPressure() async throws {
    let harness = Harness()
    let activity = { (written: UInt64) in
      ProcessActivity(
        diskBytesRead: 0,
        diskBytesWritten: written,
        interruptWakeups: written / 10,
        packageIdleWakeups: 0,
        peakFootprint: 900,
      )
    }
    let threads = [
      ThreadUsage(id: 1, name: "", isMain: true, cpuTime: .seconds(1)),
      ThreadUsage(id: 2, name: "renderer", isMain: false, cpuTime: .zero),
    ]
    harness.model.enableDebugTools(
      scan: .sample(
        appMemory: 400,
        trees: [],
        appActivity: activity(1_000),
        threads: threads,
        openDescriptorCount: 63,
        memoryPressure: .warning,
      )
    )
    await harness.model.takeDebugSample()
    let later = DebugProcessScan.sample(
      appMemory: 400,
      trees: [],
      appActivity: activity(3_000),
      threads: threads,
    )
    harness.model.debugSampler.scanProcesses = { _, _, _ in later }

    await harness.model.takeDebugSample()

    let samples = harness.model.debugHistory.samples
    #expect(samples.map(\.openDescriptorCount) == [63, nil])
    #expect(samples.map(\.memoryPressure) == [.warning, nil])
    #expect(samples.map(\.threadCount) == [2, 2])
    #expect(samples.map(\.peakMemory) == [900, 900])
    #expect(samples.map(\.activity.diskBytesWritten) == [0, 2_000])
    #expect(samples.map(\.activity.interruptWakeups) == [0, 200])
  }

  @Test func eachReportIsTimedAsTheMainActorHandledIt() async throws {
    let harness = Harness()
    harness.model.enableDebugTools()
    harness.model.receive(SessionStateReport(state: .running))

    await harness.model.takeDebugSample()

    let reports = try #require(harness.model.debugHistory.latest?.stateReports)
    #expect(reports.count == 1)
    #expect(reports.totalDuration > .zero)
  }

  @Test func aSaveOffTheMainActorCountsWithTheBytesItWrote() async throws {
    let harness = Harness()
    harness.model.enableDebugTools()

    harness.model.saveOffMain()
    try await waitUntil { harness.model.debugSampler.stateSaves.count == 1 }
    await harness.model.takeDebugSample()

    let saves = try #require(harness.model.debugHistory.latest?.stateSaves)
    #expect(saves.count == 1)
    #expect(saves.bytesWritten > 0)
  }

  @Test func theDirectoriesTheWatcherReportsCountInTheNextSample() async throws {
    let harness = Harness()
    harness.model.enableDebugTools()

    harness.watcher.onChange?([URL(fileURLWithPath: "/a"), URL(fileURLWithPath: "/b")])
    await harness.model.takeDebugSample()

    #expect(harness.model.debugHistory.latest?.fileEventCount == 2)
  }

  @Test func withTheToolsOffNoReportIsTimedAndNoFileEventCounted() async throws {
    let harness = Harness()
    harness.model.receive(SessionStateReport(state: .running))
    harness.watcher.onChange?([URL(fileURLWithPath: "/a")])

    #expect(harness.model.debugSampler.stateReports == .empty)
    #expect(harness.model.debugSampler.fileEventCount == 0)
  }
}
