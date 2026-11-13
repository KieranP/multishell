import Dispatch
import Foundation
import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelDebugToolsTests {
  /// Lets the held scan go and blocks the calling thread, the main actor here,
  /// past its end, as a stall begun mid-scan would.
  private static func stallTheMainActor(
    releasing mayScan: DispatchSemaphore,
    until scanned: DispatchSemaphore,
    seconds: Double,
  ) {
    mayScan.signal()
    scanned.wait()
    Thread.sleep(forTimeInterval: seconds)
  }

  private func harnessWithDebugTools() -> Harness {
    let harness = Harness()
    harness.model.enableDebugTools()
    return harness
  }

  @Test func turningDebugToolsOnStartsTheFrameCallbacksAndOffDropsEverySample() async {
    let harness = harnessWithDebugTools()
    #expect(harness.platform.onDisplayFrame != nil)
    await harness.model.takeDebugSample()
    #expect(harness.model.debugHistory.samples.count == 1)
    let sampling = harness.model.debugSampler.ticks

    harness.model.setDebugToolsEnabled(false)

    #expect(harness.platform.onDisplayFrame == nil)
    #expect(sampling?.isCancelled == true)
    #expect(harness.model.debugSampler.ticks == nil)
    #expect(harness.model.debugHistory.samples.isEmpty)
  }

  @Test func aSampleAfterTheToolsGoOffAndOnIsNumberedPastTheLastOneBefore() async throws {
    let harness = harnessWithDebugTools()
    await harness.model.takeDebugSample()
    await harness.model.takeDebugSample()
    let before = try #require(harness.model.debugHistory.latest?.sequence)

    harness.model.setDebugToolsEnabled(false)
    harness.model.enableDebugTools()
    await harness.model.takeDebugSample()

    #expect(try #require(harness.model.debugHistory.latest?.sequence) > before)
  }

  @Test func aSampleAskedForWhileTheToolsAreOffRecordsNothing() async {
    let harness = Harness()
    harness.model.debugSampler.scanProcesses = { _, _ in .sample(appMemory: 400, trees: []) }

    await harness.model.takeDebugSample()

    #expect(harness.model.debugHistory.samples.isEmpty)
  }

  @Test func thePanelCoversThePanesUntilAWorktreeIsClicked() {
    let harness = harnessWithDebugTools()
    harness.model.select(harness.main)

    harness.model.showDebugInfo()
    #expect(harness.model.detailContent == .cover(.debugInfo))
    #expect(!harness.model.isInView(harness.main))

    harness.model.select(harness.main)
    #expect(harness.model.detailContent == .tabGroups(harness.main))
  }

  @Test func thePanelAndTheBoardTakeEachOthersPlace() {
    let harness = harnessWithDebugTools()
    harness.model.showAgentBoard()
    harness.model.showDebugInfo()
    #expect(!harness.model.showsAgentBoard)

    harness.model.showAgentBoard()
    #expect(!harness.model.showsDebugInfo)
  }

  @Test func thePanelIsNotShownWithDebugToolsOffAndGoesWhenTheyAreTurnedOff() {
    let harness = Harness()
    harness.model.showDebugInfo()
    #expect(harness.model.detailCover == nil)

    let enabled = harnessWithDebugTools()
    enabled.model.showDebugInfo()
    enabled.model.setDebugToolsEnabled(false)
    #expect(enabled.model.detailCover == nil)
  }

  @Test func aPausedPanelHoldsItsSamplesWhileTheSidebarKeepsCounting() async {
    let harness = harnessWithDebugTools()
    await harness.model.takeDebugSample()
    harness.model.setDebugPaused(true)
    await harness.model.takeDebugSample()

    #expect(harness.model.debugTimeline(for: .oneMinute).slots.compactMap { $0 }.count == 1)
    #expect(harness.model.debugHistory.samples.count == 2)

    harness.model.setDebugPaused(false)
    #expect(harness.model.debugTimeline(for: .oneMinute).slots.compactMap { $0 }.count == 2)
  }

  @Test func aPausedMemoryTableHoldsStillAsATabCloses() async {
    let harness = harnessWithDebugTools()
    harness.model.select(harness.main)
    harness.model.newTab()
    await harness.model.takeDebugSample()
    harness.model.setDebugPaused(true)
    let held = harness.model.debugMemoryTable

    harness.model.closeActiveTab()

    #expect(harness.model.debugMemoryTable == held)
  }

  @Test(arguments: [false, true])
  func aSampleStillScanningWhenTheToolsAreTurnedOffIsDropped(turnedBackOn: Bool) async {
    let harness = harnessWithDebugTools()
    let scanHeld = DispatchSemaphore(value: 0)
    harness.model.debugSampler.scanProcesses = { _, _ in
      scanHeld.wait()
      return .sample(appMemory: 400, trees: [])
    }
    let sampling = Task { await harness.model.takeDebugSample() }
    await harness.settled()

    harness.model.setDebugToolsEnabled(false)
    if turnedBackOn { harness.model.setDebugToolsEnabled(true) }
    scanHeld.signal()
    await sampling.value

    #expect(harness.model.debugHistory.samples.isEmpty)
  }

  /// The share is the scan's CPU over the scan's own interval: timed after the
  /// main actor came back, a stall begun mid-scan read as a quarter, then fourfold.
  @Test func theAppsCPUIsMeasuredBetweenItsScansNotWhenTheMainActorTookThem() async throws {
    let harness = harnessWithDebugTools()
    let start = ContinuousClock.now
    let busySinceStart: @Sendable () -> DebugProcessScan = {
      DebugProcessScan(
        app: .sample(pid: 1, cpuTime: start.duration(to: .now)),
        trees: [],
        terminalDevices: [:],
      )
    }
    harness.model.debugSampler.scanProcesses = { _, _ in busySinceStart() }
    await harness.model.takeDebugSample()
    try await Task.sleep(for: .milliseconds(300))
    let scanStarted = AtomicFlag()
    let mayScan = DispatchSemaphore(value: 0)
    let scanned = DispatchSemaphore(value: 0)
    harness.model.debugSampler.scanProcesses = { _, _ in
      scanStarted.raise()
      mayScan.wait()
      defer { scanned.signal() }
      return busySinceStart()
    }
    let sampling = Task { await harness.model.takeDebugSample() }
    try await waitUntil { scanStarted.raised }

    Self.stallTheMainActor(releasing: mayScan, until: scanned, seconds: 0.6)
    await sampling.value

    let percent = harness.model.debugHistory.latest?.appCPUPercent ?? 0
    #expect((80...120).contains(percent), "a process busy throughout reads \(percent)%")
  }

  @Test func reportsWhileTheToolsAreOffAreNotCounted() async {
    let harness = Harness()
    harness.model.receive(SessionStateReport(state: .running))
    harness.model.enableDebugTools()

    await harness.model.takeDebugSample()

    #expect(harness.model.debugHistory.latest?.stateReportCount == 0)
  }
}
