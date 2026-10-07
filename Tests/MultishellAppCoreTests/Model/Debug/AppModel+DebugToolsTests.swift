import Dispatch
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelDebugToolsTests {
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
    let sampling = harness.model.debugSampling

    harness.model.setDebugToolsEnabled(false)

    #expect(harness.platform.onDisplayFrame == nil)
    #expect(sampling?.isCancelled == true)
    #expect(harness.model.debugSampling == nil)
    #expect(harness.model.debugHistory.samples.isEmpty)
  }

  @Test func aSampleAskedForWhileTheToolsAreOffRecordsNothing() async {
    let harness = Harness()
    harness.model.scanDebugProcesses = { _, _ in .sample(appMemory: 400, trees: []) }

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

  @Test(arguments: [false, true])
  func aSampleStillScanningWhenTheToolsAreTurnedOffIsDropped(turnedBackOn: Bool) async {
    let harness = harnessWithDebugTools()
    let scanHeld = DispatchSemaphore(value: 0)
    harness.model.scanDebugProcesses = { _, _ in
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

  @Test func reportsWhileTheToolsAreOffAreNotCounted() async {
    let harness = Harness()
    harness.model.receive(SessionStateReport(state: .running))
    harness.model.enableDebugTools()

    await harness.model.takeDebugSample()

    #expect(harness.model.debugHistory.latest?.stateReportCount == 0)
  }
}
