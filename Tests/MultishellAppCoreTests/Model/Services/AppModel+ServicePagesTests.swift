import Foundation
import Observation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit
@testable import MultishellServices

@Suite(.serialized) @MainActor
struct AppModelServicePagesTests {
  @Test func aBranchWithoutAPullRequestOffersOneAndSaysWhetherItIsPushed() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)
    #expect(
      harness.model.pullRequestPage(of: feat)
        == .noPullRequest(branch: "feat", isPushed: false)
    )

    try await harness.pushToGitHubOrigin(feat)
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)
    #expect(
      harness.model.pullRequestPage(of: feat)
        == .noPullRequest(branch: "feat", isPushed: true)
    )
  }

  @Test func checksNotYetReadHoldTheMergeBack() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    host.answer(.success([.sample(number: 9, headBranch: "feat")]))
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)
    let pullRequest = try #require(harness.model.services(of: feat).pullRequest)

    let readiness = harness.model.mergeReadiness(of: pullRequest, in: feat)

    #expect(readiness.blockers == [.checksNotRead])
  }

  @Test func aFailedChecksReadWithNoneReadIsTheChecksStepsOwn() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    host.answer(.success([.sample(number: 9, headBranch: "feat")]))
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)
    harness.model.select(feat)
    harness.model.setShowsFilesPanel(true)
    harness.model.setFilesPanelMode(.pullRequest)
    let pullRequest = try #require(harness.model.services(of: feat).pullRequest)
    harness.model.remoteState.checks[feat.id] = PullRequestChecks(
      pullRequestNumber: 9,
      headCommit: pullRequest.headCommit,
      checks: nil,
      failure: .failed("HTTP 502"),
    )

    let path = harness.model.mergePath(of: pullRequest, in: feat)

    let step = try #require(path.steps.first { $0.kind == .checksNotRead })
    #expect(path.hint(of: step, base: "main", host: "GitHub")?.hasSuffix("HTTP 502") == true)
    #expect(path.staleChecksNote == nil)
    #expect(path.end == .waits(.checksRead))
    #expect(path.endHint(host: "GitHub") == "Once Multishell can read the checks")
  }

  @Test func thePagesRedrawWhenABranchIsPushed() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)
    let changed = AtomicFlag()
    withObservationTracking {
      _ = harness.model.pullRequestPage(of: feat)
    } onChange: {
      changed.raise()
    }

    _ = try await harness.git.run(["push", "-q", "-u", "origin", "feat"], in: feat.path)
    await harness.model.refreshBranchScan(of: harness.project)

    #expect(changed.raised)
  }

  @Test func aReadThatChangesNothingRedrawsNoPage() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    host.answer(.success([.sample(number: 9, headBranch: "feat")]))
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)
    let changed = AtomicFlag()
    withObservationTracking {
      _ = harness.model.pullRequestPage(of: feat)
    } onChange: {
      changed.raise()
    }

    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(!changed.raised)
  }

  @Test func checksReadForAnEarlierHeadDoNotDecideTheNewOnes() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    host.answer(.success([.sample(number: 9, headBranch: "feat", headCommit: "a")]))
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)
    harness.model.remoteState.checks[feat.id] = PullRequestChecks(
      pullRequestNumber: 9,
      headCommit: "a",
      checks: [],
    )
    host.answer(.success([.sample(number: 9, headBranch: "feat", headCommit: "b")]))
    await harness.model.refreshServices(ofProject: harness.project.id)
    let pullRequest = try #require(harness.model.services(of: feat).pullRequest)

    #expect(harness.model.mergeReadiness(of: pullRequest, in: feat).blockers == [.checksNotRead])
  }

  @Test func theCIPageSaysWhenTheProviderDisownsTheRepository() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "feat"], in: feat.path)
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    provider.failRecent(.notHosted)
    harness.model.remoteState.ciRuns[harness.project.id]?.notHostedSince = .distantPast
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(harness.model.ciPage(of: feat) == .notHosted(provider: "CircleCI"))
  }

  @Test func aMergedPullRequestTheBranchWentPastIsShownWithANewOneOffered() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    let merged = PullRequest.sample(
      number: 33,
      state: .merged,
      headBranch: "feat",
      headCommit: try await harness.tip(of: feat),
    )
    _ = try await harness.git.run(["commit", "-q", "--allow-empty", "-m", "after"], in: feat.path)
    host.answer(.success([merged]))
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(harness.model.pullRequestPage(of: feat) == .pullRequest(merged))
    #expect(harness.model.pullRequestMenuItem(for: feat) == .create(isPublishing: false))
    #expect(harness.model.mergePath(of: merged, in: feat).end == .merged(isOutgrown: true))
  }

  @Test func aWorktreeWithNoBranchHasNoRunsToFind() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.connectServices()
    try harness.writeCIConfiguration()
    let directory = harness.root.appendingPathComponent("detached", isDirectory: true)
    _ = try await harness.git.run(
      ["worktree", "add", "-q", "--detach", directory.path],
      in: harness.project.path,
    )
    await harness.model.refreshWorktrees(of: harness.project)
    let detached = try #require(
      harness.model.workspace.worktrees(of: harness.project.id).first { $0.branch == nil }
    )

    #expect(harness.model.ciPage(of: detached) == .notApplicable)
  }

  @Test func theTrunkHasNoPullRequestToOffer() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.connectServices()
    let main = try #require(harness.worktree(onBranch: "main"))
    await harness.model.refreshBranchScan(of: harness.project)

    #expect(harness.model.pullRequestPage(of: main) == .trunk)
  }

  @Test func aWorktreeWithNoBranchSaysSoRatherThanCallingItTheTrunk() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.connectServices()
    let directory = harness.root.appendingPathComponent("detached", isDirectory: true)
    _ = try await harness.git.run(
      ["worktree", "add", "-q", "--detach", directory.path],
      in: harness.project.path,
    )
    await harness.model.refreshWorktrees(of: harness.project)
    let detached = try #require(
      harness.model.workspace.worktrees(of: harness.project.id).first { $0.branch == nil }
    )

    #expect(
      harness.model.pullRequestPage(of: detached).emptyText?.title
        == "A worktree with no branch has no pull request"
    )
  }

  @Test func anIntegrationTurnedOffSaysSoOnItsPage() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.connectServices()
    let main = try #require(harness.worktree(onBranch: "main"))

    harness.model.setIntegration(.gitHub, isEnabled: false, for: harness.project)
    harness.model.setIntegration(.circleCI, isEnabled: false, for: harness.project)

    #expect(harness.model.pullRequestPage(of: main) == .turnedOff)
    #expect(harness.model.ciPage(of: main) == .turnedOff)
  }

  @Test func theCIPageSaysWhyThereIsNoRun() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    await harness.model.refreshServices(ofProject: harness.project.id)
    #expect(harness.model.ciPage(of: feat) == .notConfigured)

    try harness.writeCIConfiguration()
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)
    #expect(harness.model.ciPage(of: feat) == .notPushed(branch: "feat"))

    try await harness.pushToGitHubOrigin(feat)
    provider.answer(recent: [])
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)
    #expect(harness.model.ciPage(of: feat) == .noRuns(branch: "feat"))
  }

  @Test func aListNeverReadIsNotTakenForNoPullRequest() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    await harness.model.refreshBranchScan(of: harness.project)
    #expect(harness.model.pullRequestPage(of: feat) == .notRead(problem: nil))
    #expect(harness.model.pullRequestMenuItem(for: feat) == nil)
    #expect(harness.model.ciPage(of: feat) == .notRead(problem: nil))

    host.answer(.failure(.loggedOut))
    provider.answer(recent: [])
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(harness.model.pullRequestPage(of: feat) == .notRead(problem: "GitHub is not logged in"))
    #expect(harness.model.pullRequestMenuItem(for: feat) == nil)
    #expect(harness.model.ciPage(of: feat) == .noRuns(branch: "feat"), "CI answered")
  }

  @Test func aServicesPageWhoseToolIsGoneShowsFilesUntilOneConnects() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.store.setFilesPanelMode(.ciRuns)

    #expect(harness.model.shownFilesPanelMode == .files)
    harness.connectServices()
    #expect(harness.model.shownFilesPanelMode == .ciRuns)
  }
}
