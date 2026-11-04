import Foundation
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit
@testable import MultishellServices

@Suite(.serialized) @MainActor
struct AppModelServiceReadsTests {
  @Test func upstreamsFirstSeenAfterAReadAreAskedAloneOnTheNextRead() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    await harness.model.refreshServices(ofProject: harness.project.id)
    #expect(host.askedBranches.isEmpty)
    try await harness.pushToGitHubOrigin(feat)

    await harness.model.refreshBranchScan(of: harness.project)

    try await waitUntil { host.askedBranches == ["feat"] && harness.servicesAreSettled() }
  }

  @Test func aWorktreeCheckedOutOntoAnotherBranchKeepsNoneOfTheOldOnesServices() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    host.answer(.success([.sample(number: 9, headBranch: "feat")]))
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    _ = try await harness.git.run(["checkout", "-q", "-b", "other"], in: feat.path)
    await harness.model.refreshWorktrees(of: harness.project)

    let other = try #require(harness.worktree(onBranch: "other"))
    #expect(!harness.model.services(of: other).showsAnything)
    #expect(harness.model.remoteState.upstreams[other.id] == nil)
  }

  @Test func aReadUnderAnIntegrationTurnedOffDisturbsNoOtherProjectsPage() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    host.answer(.success([]))
    let other = try await harness.addSecondProject()
    let otherMain = try #require(harness.model.workspace.worktrees(of: other.id).first)
    harness.model.setIntegration(.circleCI, isEnabled: false, for: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    let model = harness.model
    let fired = AtomicFlag()
    withObservationTracking {
      _ = model.ciPage(of: otherMain)
    } onChange: {
      fired.raise()
    }
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(!fired.raised)
  }

  @Test func aReadSettlingAfterTheAppLeftTheFrontAsksNothingAndIsLeftDue() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    let id = harness.project.id
    harness.model.scheduleServicesRefresh(of: id)
    let pending = try #require(harness.model.remoteState.pendingReads[id])

    harness.platform.isActive = false
    await pending.value

    #expect(host.calls.isEmpty)
    #expect(harness.model.remoteState.readLog.isDue(id, at: .now))
  }

  @Test func anUpstreamMovingInTheBackgroundSchedulesNoRead() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.connectServices()
    harness.platform.isActive = false

    harness.model.scheduleServicesRefresh(of: harness.project.id)

    #expect(harness.model.remoteState.pendingReads[harness.project.id] == nil)
  }

  @Test func aRunsOnlyReadQueuedBehindAReadListsNoPullRequestsAgain() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    defer { host.releaseHeldReads() }
    host.holdList()
    let id = harness.project.id
    let read = Task { _ = await harness.model.refreshServices(ofProject: id) }
    try await waitUntil { host.calls == ["list"] }

    await harness.model.refreshServices(ofProject: id, readsPullRequests: false)
    host.releaseHeldReads()
    await read.value
    try await waitUntil { harness.servicesAreSettled() }

    #expect(host.calls == ["list"])
    #expect(provider.calls.filter { $0 == "recent" }.count == 2)
  }

  @Test func aListLandingAfterItsToolLeftThePathLeavesNoAnswerTime() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    defer { host.releaseHeldReads() }
    host.holdList()
    let id = harness.project.id
    let read = Task { _ = await harness.model.refreshServices(ofProject: id) }
    try await waitUntil { host.calls == ["list"] }

    harness.model.remoteState.connections = .empty
    host.releaseHeldReads()
    await read.value

    #expect(harness.model.remoteState.pullRequestsAnsweredAt[id] == nil)
  }

  @Test func runsLandingAfterTheirToolLeftThePathLeaveNoAnswerTime() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    defer { provider.releaseHeldReads() }
    provider.holdRecent()
    let id = harness.project.id
    let read = Task { _ = await harness.model.refreshServices(ofProject: id) }
    try await waitUntil { provider.calls.contains("recent") }

    harness.model.remoteState.connections = .empty
    provider.releaseHeldReads()
    await read.value

    #expect(harness.model.remoteState.ciRunsAnsweredAt[id] == nil)
  }

  @Test func anUpstreamMovingInTheBackgroundIsReadOnTheReturnHoweverRecentTheLastRead()
    async throws
  {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.connectServices()
    await harness.model.refreshServices(ofProject: harness.project.id)
    harness.platform.isActive = false

    harness.model.scheduleServicesRefresh(of: harness.project.id)

    #expect(
      harness.model.remoteState.readLog.isDue(
        harness.project.id,
        at: .now,
        interval: ServiceReadInterval.activation,
      )
    )
  }

  @Test func aReadSpanningAnIntegrationTurnedOffAndOnAgainIsNotKept() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    defer { host.releaseHeldReads() }
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    host.answer(.success([.sample(number: 9, headBranch: "feat")]))
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)
    host.holdList()
    host.answer(.failure(.failed("offline")))
    let read = Task { _ = await harness.model.refreshServices(ofProject: harness.project.id) }
    try await waitUntil { host.calls.count == 2 }

    harness.model.setIntegration(.gitHub, isEnabled: false, for: harness.project)
    harness.model.setIntegration(.gitHub, isEnabled: true, for: harness.project)
    host.releaseHeldReads()
    await read.value

    #expect(
      harness.model.services(of: feat).pullRequest == nil,
      "the list read before it went is not this one's",
    )
  }

  @Test func turningOneIntegrationOffMidReadReadsTheOtherAgainAtOnce() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    defer { provider.releaseHeldReads() }
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    host.answer(.success([.sample(number: 9, headBranch: "feat")]))
    await harness.model.refreshBranchScan(of: harness.project)
    provider.holdRecent()
    let read = Task { _ = await harness.model.refreshServices(ofProject: harness.project.id) }
    try await waitUntil { provider.calls.contains("recent") }

    harness.model.setIntegration(.circleCI, isEnabled: false, for: harness.project)
    provider.releaseHeldReads()
    await read.value
    try await waitUntil { harness.servicesAreSettled() }

    #expect(harness.model.services(of: feat).pullRequest?.number == 9)
  }

  @Test func anIntegrationTurnedOffMidReadInTheBackgroundLeavesTheReadDueNotRun() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    defer { provider.releaseHeldReads() }
    provider.holdRecent()
    let id = harness.project.id
    let read = Task { _ = await harness.model.refreshServices(ofProject: id) }
    try await waitUntil { provider.calls.contains("recent") }

    harness.platform.isActive = false
    harness.model.setIntegration(.circleCI, isEnabled: false, for: harness.project)
    provider.releaseHeldReads()
    await read.value
    try await waitUntil { harness.servicesAreSettled() }

    #expect(host.calls == ["list"], "nothing is asked in the background")
    #expect(harness.model.remoteState.readLog.isDue(id, at: .now))
  }

  @Test func aReadAskedForDuringAnotherFollowsIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    defer { host.releaseHeldReads() }
    host.holdList()
    let first = Task { _ = await harness.model.refreshServices(ofProject: harness.project.id) }
    try await waitUntil { host.calls == ["list"] }

    await harness.model.refreshServices(ofProject: harness.project.id)
    host.releaseHeldReads()
    await first.value

    try await waitUntil({ host.calls.count == 2 }, seconds: 3)
    #expect(host.calls == ["list", "list"], "what moved during the first is read after it")
  }

  @Test func aReadAskedForDuringAnotherWaitsForTheFrontWhereTheAppWentBehind() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    defer { host.releaseHeldReads() }
    host.holdList()
    let first = Task { _ = await harness.model.refreshServices(ofProject: harness.project.id) }
    try await waitUntil { host.calls == ["list"] }
    await harness.model.refreshServices(ofProject: harness.project.id)

    harness.platform.isActive = false
    host.releaseHeldReads()
    await first.value

    #expect(harness.model.remoteState.readLog.isDue(harness.project.id, at: .now))
    try await waitUntil { harness.servicesAreSettled() }
    #expect(host.calls == ["list"])
  }

  @Test func aReadWithNoToolToAskDoesNotCountTheProjectAsked() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }

    await harness.model.refreshServices(ofProject: harness.project.id)
    let (host, _) = harness.connectServices()
    await harness.model.pollServices()

    #expect(host.calls == ["list"], "due at once, not an interval after the empty read")
  }

  @Test func aPushMovingTheUpstreamReadsTheServicesAgain() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "feat"], in: feat.path)
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)
    #expect(host.calls == ["list"])

    _ = try await harness.git.run(["commit", "-q", "--allow-empty", "-m", "work"], in: feat.path)
    _ = try await harness.git.run(["push", "-q", "origin", "feat"], in: feat.path)
    await harness.model.refreshBranchScan(of: harness.project)

    try await waitUntil({ host.calls.count == 2 }, seconds: 5)
    #expect(host.calls == ["list", "list"])
  }

  @Test func aBranchCutFromTheTrunkThatStillTracksItTakesNoneOfTheTrunksServices() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    try await harness.addOrigin()
    _ = try await harness.git.run(
      ["branch", "-q", "--set-upstream-to=origin/main", "main"],
      in: harness.project.path,
    )
    let directory = harness.root.appendingPathComponent("feat", isDirectory: true)
    _ = try await harness.git.run(
      ["worktree", "add", "-q", "--track", "-b", "feat", directory.path, "origin/main"],
      in: harness.project.path,
    )
    await harness.model.refreshWorktrees(of: harness.project)
    let feat = try #require(harness.worktree(onBranch: "feat"))
    provider.answer(recent: [.sample(id: "trunk", branch: "main")])
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(harness.model.services(of: feat).ciRun == nil, "main's run is not feat's")
    #expect(
      harness.model.pullRequestPage(of: feat)
        == .noPullRequest(branch: "feat", isPushed: false)
    )
    let main = try #require(harness.worktree(onBranch: "main"))
    #expect(harness.model.services(of: main).ciRun?.id == "trunk", "the trunk's own row keeps it")
  }

  @Test func aBranchTrackingALocalBranchIsNotPushed() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    try await harness.addOrigin()
    _ = try await harness.git.run(["branch", "-q", "stack"], in: harness.project.path)
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["branch", "-q", "--set-upstream-to=stack"], in: feat.path)
    provider.answer(recent: [.sample(id: "stack-run", branch: "stack")])
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(harness.model.services(of: feat).ciRun == nil, "stack's run is not feat's")
    #expect(
      harness.model.pullRequestPage(of: feat)
        == .noPullRequest(branch: "feat", isPushed: false)
    )
  }
}
