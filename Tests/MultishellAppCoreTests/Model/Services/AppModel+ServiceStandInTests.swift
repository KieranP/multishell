import Foundation
import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellServices

@Suite(.serialized) @MainActor
struct AppModelServiceStandInTests {
  private static func standIn(
    numbered number: Int,
    at tip: String,
    checkNamed check: String = "build",
  ) throws -> ServiceStandIn {
    try ServiceStandIn(
      json: """
        {"pullRequests": [{"number": \(number), "title": "Feat", "state": "open",
          "headBranch": "feat", "headCommit": "\(tip)", "headRepository": "me/demo",
          "checks": [{"name": "\(check)", "status": "passed"}]}]}
        """
    )
  }

  @Test func aStandInAnswersWithItsPullRequestAndRunUntilCleared() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    await harness.model.refreshBranchScan(of: harness.project)
    let tip = try await harness.tip(of: feat)
    let standIn = try ServiceStandIn(
      json: """
        {"pullRequests": [{"number": 7, "title": "Feat", "state": "open", "headBranch": "feat",
                           "headCommit": "\(tip)", "headRepository": "me/demo"}],
         "ciRuns": [{"id": "r1", "branch": "feat", "commit": "\(tip)", "status": "passed"}]}
        """
    )

    await harness.model.standInServices(standIn)
    let answered = harness.model.services(of: feat)
    await harness.model.standInServices(nil)

    #expect(answered.pullRequest?.number == 7)
    #expect(answered.ciRun?.id == "r1")
    #expect(!harness.model.services(of: feat).showsAnything)
  }

  @Test func aStandInAnswersOverAToolsReadAlreadyUnderWay() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    await harness.model.refreshBranchScan(of: harness.project)
    let tip = try await harness.tip(of: feat)
    host.answer(.success([.sample(number: 9, headBranch: "feat", headCommit: tip)]))
    host.holdList()
    let toolRead = Task { _ = await harness.model.refreshServices(ofProject: harness.project.id) }
    try await waitUntil { host.calls == ["list"] }

    let standIn = try Self.standIn(numbered: 7, at: tip)
    let staging = Task { await harness.model.standInServices(standIn) }
    try await waitUntil { harness.model.remoteState.standIn != nil }
    host.releaseHeldReads()
    await staging.value
    await toolRead.value

    #expect(harness.model.services(of: feat).pullRequest?.number == 7)
  }

  @Test func anOpenPullRequestPageReadsTheStandInsChecksAtOnce() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    await harness.model.refreshBranchScan(of: harness.project)
    let tip = try await harness.tip(of: feat)
    harness.model.select(feat)
    harness.model.setShowsFilesPanel(true)
    await harness.model.standInServices(try Self.standIn(numbered: 7, at: tip))
    harness.model.setFilesPanelMode(.pullRequest)
    await harness.model.pollPanelServices()

    await harness.model.standInServices(try Self.standIn(numbered: 7, at: tip, checkNamed: "lint"))

    #expect(harness.model.remoteState.checks[feat.id]?.checks?.map(\.name) == ["lint"])
  }

  @Test func aChecksReadUnderWayDoesNotOverwriteTheStandInsChecks() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    await harness.model.refreshBranchScan(of: harness.project)
    let tip = try await harness.tip(of: feat)
    host.answer(.success([.sample(number: 7, headBranch: "feat", headCommit: tip)]))
    host.answerChecks([
      PullRequestCheck(name: "tool", workflow: nil, status: .passed, isRequired: false, link: nil)
    ])
    await harness.model.refreshServices(ofProject: harness.project.id)
    harness.model.select(feat)
    harness.model.setShowsFilesPanel(true)
    harness.model.setFilesPanelMode(.pullRequest)
    host.holdChecks()
    let toolRead = Task { await harness.model.pollPanelServices() }
    try await waitUntil { host.calls.contains("checks #7") }

    let standIn = try Self.standIn(numbered: 7, at: tip, checkNamed: "lint")
    let standingIn = Task { await harness.model.standInServices(standIn) }
    try await waitUntil { harness.model.remoteState.standIn != nil }
    host.releaseHeldReads()
    await standingIn.value
    await toolRead.value

    #expect(harness.model.remoteState.checks[feat.id]?.checks?.map(\.name) == ["lint"])
  }

  @Test func everyRepositoryRunsOnTheStandInsCI() async throws {
    let harness = Harness()
    let provider = try ServiceStandIn(json: "{}").ciProvider

    #expect(await harness.model.runsOn(provider, project: harness.project))
  }

  @Test func clearingAStandInBeforeAnyToolsWereAdoptedConnectsNone() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }

    await harness.model.standInServices(try ServiceStandIn(json: "{}"))
    await harness.model.standInServices(nil)

    #expect(harness.model.remoteState.connections.pullRequestHosts.isEmpty)
    #expect(harness.model.remoteState.connections.ciProviders.isEmpty)
    #expect(harness.model.remoteState.toolDetection == .empty)
  }

  @Test func anOpenPageIsReadThroughTheStandInWithTheAppBehind() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    await harness.model.refreshBranchScan(of: harness.project)
    let tip = try await harness.tip(of: feat)
    harness.model.select(feat)
    harness.model.setShowsFilesPanel(true)
    await harness.model.standInServices(try Self.standIn(numbered: 7, at: tip))
    harness.model.setFilesPanelMode(.pullRequest)
    harness.platform.isActive = false

    await harness.model.standInServices(try Self.standIn(numbered: 7, at: tip, checkNamed: "lint"))

    #expect(harness.model.remoteState.checks[feat.id]?.checks?.map(\.name) == ["lint"])
  }

  @Test func theIntegrationsPageCountsTheStandInAsInstalled() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }

    await harness.model.standInServices(try ServiceStandIn(json: "{}"))

    #expect(harness.model.integrationAvailability(.gitHub) != .notInstalled)
    #expect(harness.model.integrationAvailability(.circleCI) != .notInstalled)
  }

  @Test func clearingWithNoStandInDropsNothingRead() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let changesBefore = harness.model.remoteState.integrationChanges

    await harness.model.standInServices(nil)

    #expect(harness.model.remoteState.integrationChanges == changesBefore)
  }

  @Test func aStandInWhoseAskerHungUpStopsWaitingOnAHeldRead() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    await harness.model.refreshBranchScan(of: harness.project)
    host.holdList()
    let toolRead = Task { _ = await harness.model.refreshServices(ofProject: harness.project.id) }
    try await waitUntil { host.calls == ["list"] }
    let standIn = try ServiceStandIn(json: "{}")
    let ended = AtomicFlag()
    let standingIn = Task {
      await harness.model.standInServices(standIn)
      ended.raise()
    }
    try await waitUntil { harness.model.remoteState.standIn != nil }

    standingIn.cancel()
    try await waitUntil({ ended.raised }, seconds: 10)
    let endedWhileHeld = ended.raised
    host.releaseHeldReads()
    await standingIn.value
    await toolRead.value

    #expect(endedWhileHeld)
  }
}
