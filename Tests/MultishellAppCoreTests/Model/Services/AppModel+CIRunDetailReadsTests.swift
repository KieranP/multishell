import Foundation
import Observation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellServices

@Suite(.serialized) @MainActor
struct AppModelCIRunDetailReadsTests {
  private static func readShownRunDetails(
    of worktree: Worktree,
    in harness: GitHarness,
  )
    async throws
  {
    let run = try #require(harness.model.services(of: worktree).ciRun)
    await harness.model.readCIRunDetails(of: run, for: worktree)
  }

  @Test func aRunThatIsNoLongerShownTakesItsWorkflowsWithIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    provider.answer(recent: [.sample(id: "r1", branch: "feat")], workflows: [])
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)
    try await Self.readShownRunDetails(of: feat, in: harness)

    provider.answer(recent: [.sample(id: "r2", branch: "feat")])
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(harness.model.remoteState.ciWorkflows["r1"] == nil)
  }

  @Test func workflowsLandingAfterTheProviderWasTurnedOffAreNotKept() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    defer { provider.releaseHeldReads() }
    try harness.writeCIConfiguration()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    provider.answer(recent: [.sample(id: "r1", branch: "feat")], workflows: [])
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)
    provider.holdWorkflows()
    let run = try #require(harness.model.services(of: feat).ciRun)
    let read = Task { await harness.model.readCIRunDetails(of: run, for: feat) }
    try await waitUntil { provider.calls.contains("workflows r1") }

    harness.model.setIntegration(.circleCI, isEnabled: false, for: harness.project)
    provider.releaseHeldReads()
    await read.value

    #expect(harness.model.remoteState.ciWorkflows["r1"] == nil)
    #expect(harness.model.remoteState.workflowsReadAt["r1"] == nil)
  }

  @Test func aRunsWorkflowsReadWhileItRanAreReadAgainOnceItHasFinished() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    let running = CIWorkflow(name: "build", status: .running, jobs: [])
    provider.answer(
      recent: [.sample(id: "r1", branch: "feat", status: .running)],
      workflows: [running],
    )
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)
    try await Self.readShownRunDetails(of: feat, in: harness)

    let passed = CIWorkflow(name: "build", status: .passed, jobs: [])
    provider.answer(
      recent: [.sample(id: "r1", branch: "feat", status: .passed)],
      workflows: [passed],
    )
    await harness.model.refreshServices(ofProject: harness.project.id)
    try await Self.readShownRunDetails(of: feat, in: harness)

    let run = try #require(harness.model.services(of: feat).ciRun)
    #expect(harness.model.ciWorkflows(ofRun: run) == [passed])
  }

  @Test func aRunUnderWayIsNotAskedAgainEachTimeItsListAppears() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    let feat = try await harness.createWorktree(onBranch: "feat")
    let running = CIRun.sample(id: "r1", branch: "feat", status: .running)

    await harness.model.readCIRunDetails(of: running, for: feat)
    await harness.model.readCIRunDetails(of: running, for: feat)

    #expect(provider.calls.filter { $0.hasPrefix("workflows") } == ["workflows r1"])
  }

  @Test func aRunsWorkflowsAskedForTwiceAtOnceAreReadOnce() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    defer { provider.releaseHeldReads() }
    try harness.writeCIConfiguration()
    let feat = try await harness.createWorktree(onBranch: "feat")
    let running = CIRun.sample(id: "r1", branch: "feat", status: .running)
    provider.holdWorkflows()

    let first = Task { await harness.model.readCIRunDetails(of: running, for: feat) }
    try await waitUntil { provider.calls.contains("workflows r1") }
    let secondDone = Recorder<Bool>()
    let second = Task {
      await harness.model.readCIRunDetails(of: running, for: feat)
      secondDone.record(true)
    }
    try await waitUntil {
      !secondDone.received.isEmpty || provider.calls.filter { $0 == "workflows r1" }.count > 1
    }
    provider.releaseHeldReads()
    await first.value
    await second.value

    #expect(provider.calls.filter { $0 == "workflows r1" } == ["workflows r1"])
  }

  @Test func anEarlierFailedRunsReportIsReadAsItsRowOpens() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    let feat = try await harness.createWorktree(onBranch: "feat")
    let earlier = CIRun.sample(id: "r0", branch: "feat", status: .failed)

    await harness.model.readCIRunDetails(of: earlier, for: feat)

    #expect(provider.calls.contains("report r0"))
    #expect(harness.model.failureReport(of: earlier) != nil)
  }

  @Test func aRunsReportAskedForTwiceAtOnceIsReadOnce() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    defer { provider.releaseHeldReads() }
    try harness.writeCIConfiguration()
    let feat = try await harness.createWorktree(onBranch: "feat")
    let failed = CIRun.sample(id: "r1", branch: "feat", status: .failed)
    provider.holdReports()

    let first = Task { await harness.model.readCIRunDetails(of: failed, for: feat) }
    try await waitUntil { provider.calls.contains("report r1") }
    let secondDone = Recorder<Bool>()
    let second = Task {
      await harness.model.readCIRunDetails(of: failed, for: feat)
      secondDone.record(true)
    }
    try await waitUntil {
      !secondDone.received.isEmpty || provider.calls.filter { $0 == "report r1" }.count > 1
    }
    provider.releaseHeldReads()
    await first.value
    await second.value

    #expect(provider.calls.filter { $0 == "report r1" } == ["report r1"])
  }

  @Test func aReReadThatFindsTheSameWorkflowsRedrawsNothing() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    let feat = try await harness.createWorktree(onBranch: "feat")
    let running = CIRun.sample(id: "r1", branch: "feat", status: .running)
    await harness.model.readCIRunDetails(of: running, for: feat)
    harness.model.remoteState.workflowsReadAt["r1"] = .distantPast
    let changed = AtomicFlag()
    withObservationTracking {
      _ = harness.model.ciWorkflows(ofRun: running)
    } onChange: {
      changed.raise()
    }

    await harness.model.readCIRunDetails(of: running, for: feat)

    #expect(provider.calls.filter { $0 == "workflows r1" }.count == 2)
    #expect(!changed.raised)
  }
}
