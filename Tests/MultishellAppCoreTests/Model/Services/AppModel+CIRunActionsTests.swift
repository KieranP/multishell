import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellServices

@Suite(.serialized) @MainActor
struct AppModelCIRunActionsTests {
  @Test func theShownRunsWorkflowsAreReadForItsPopoverAndItsBranchOpened() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    let workflow = CIWorkflow(
      name: "build",
      status: .passed,
      jobs: [CIJob(id: nil, name: "test", status: .passed)],
    )
    provider.answer(recent: [.sample(id: "r1", branch: "feat")], workflows: [workflow])
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)
    #expect(harness.model.ciMenuIntegration(for: feat) == .circleCI)
    #expect(harness.model.ciWorkflows(of: feat) == nil, "read only when asked")

    await harness.model.readCIWorkflows(of: feat)
    await harness.model.openCIRuns(of: feat)

    #expect(harness.model.ciWorkflows(of: feat) == [workflow])
    #expect(provider.calls.suffix(2) == ["workflows r1", "open feat"])
  }

  @Test func theCIPageOpensItsBranchWhereOnlyTheHistoryFoundARun() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    provider.answer(recent: [], history: [.sample(id: "h1", branch: "feat")])
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)
    harness.model.select(feat)
    harness.model.setShowsFilesPanel(true)
    harness.model.setFilesPanelMode(.ciRuns)
    try await waitUntil {
      harness.model.ciPage(of: feat) == .run(.sample(id: "h1", branch: "feat"))
    }

    await harness.model.openCIRuns(of: feat)

    #expect(provider.calls.last == "open feat")
  }

  @Test func aJobOpensThroughItsProvider() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    let feat = try await harness.createWorktree(onBranch: "feat")

    await harness.model.openCIJob(CIJob(id: "j2", name: "test", status: .failed), of: feat)

    #expect(provider.calls.last == "open job j2")
  }
}
