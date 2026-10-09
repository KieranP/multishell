import MultishellCore
import MultishellGitKit
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelDebugSamplingTests {
  @Test func aSampleAddsUpTheAppAndEveryChildAndTheReportsSinceTheLast() async throws {
    let harness = Harness()
    harness.model.enableDebugTools(
      scan: .sample(appMemory: 400, trees: [(10, [10, 11]), (20, [20])]))
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
}
