import Foundation
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit
@testable import MultishellServices

@Suite(.serialized) @MainActor
struct AppModelPullRequestReadsTests {
  @Test func aPushedWorktreeShowsThePullRequestItsBranchHeads() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    host.answer(
      .success([
        .sample(number: 9, headBranch: "feat", headCommit: try await harness.tip(of: feat))
      ])
    )

    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(harness.model.services(of: feat).pullRequest?.number == 9)
    #expect(harness.model.services(of: feat).pullRequestIntegration == .gitHub)
    #expect(host.calls == ["list"], "one call for the whole project")
  }

  @Test func aMergedPullRequestTheListLeftOutIsFoundByItsBranchAndIsProof() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["commit", "-q", "--allow-empty", "-m", "work"], in: feat.path)
    try await harness.pushToGitHubOrigin(feat)
    let tip = try await harness.tip(of: feat)
    host.answer(branch: "feat", .success([.sample(number: 9, state: .merged, headCommit: tip)]))

    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(host.askedBranches == ["feat"])
    #expect(harness.model.services(of: feat).pullRequest?.number == 9)
    #expect(
      harness.model.mergeState(of: feat) == .merged(.pullRequest(number: 9), into: "origin/main")
    )
  }

  @Test func aBranchTheListNamesAndOneNeverPushedAreNotAskedAlone() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.createWorktree(onBranch: "unpushed")
    try await harness.pushToGitHubOrigin(feat)
    host.answer(.success([.sample(number: 9, headBranch: "feat")]))

    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(harness.model.services(of: feat).pullRequest?.number == 9)
    #expect(host.askedBranches.isEmpty)
  }

  @Test func aForksSameNamedPullRequestInTheListDoesNotStopTheBranchBeingAskedAlone()
    async throws
  {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    host.answer(.success([.sample(number: 30, headBranch: "feat", owner: "someone-else")]))
    host.answer(branch: "feat", .success([.sample(number: 9, state: .merged)]))

    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(host.askedBranches == ["feat"])
    #expect(harness.model.services(of: feat).pullRequest?.number == 9)
  }

  @Test func aBranchWithNoOpenPullRequestIsNotAskedAgainUntilItIsPushedTo() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    host.answer(branch: "feat", .success([.sample(number: 9, state: .closed)]))
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    await harness.model.refreshServices(ofProject: harness.project.id)
    #expect(host.askedBranches == ["feat"])
    #expect(harness.model.services(of: feat).pullRequest?.number == 9)

    try await harness.commitFile("more", in: feat)
    _ = try await harness.git.run(
      ["update-ref", "refs/remotes/origin/feat", "HEAD"],
      in: feat.path,
    )
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)
    #expect(host.askedBranches == ["feat", "feat"])
  }

  @Test func anOpenPullRequestFoundByItsBranchIsAskedForEveryRead() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    host.answer(branch: "feat", .success([.sample(number: 9, state: .open)]))
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)
    host.answer(branch: "feat", .success([.sample(number: 9, state: .merged)]))

    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(host.askedBranches == ["feat", "feat"])
    #expect(harness.model.services(of: feat).pullRequest?.state == .merged)
  }

  @Test func aBranchAskedAloneIsAskedAgainOnceTheListHasNamedIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    host.answer(branch: "feat", .success([]))
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)
    host.answer(.success([.sample(number: 12, headBranch: "feat")]))
    await harness.model.refreshServices(ofProject: harness.project.id)
    host.answer(.success([]))
    host.answer(branch: "feat", .success([.sample(number: 12, state: .merged)]))

    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(host.askedBranches == ["feat", "feat"])
    #expect(harness.model.services(of: feat).pullRequest?.state == .merged)
  }

  @Test func aBranchTheRemoteDeletedIsStillAskedAlone() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "feat"], in: feat.path)
    _ = try await harness.git.run(["push", "-q", "origin", "--delete", "feat"], in: feat.path)

    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(harness.model.remoteState.upstreams[feat.id]?.tip == nil)
    #expect(host.askedBranches == ["feat"])
  }

  @Test func aMergedPullRequestFoundAloneForABranchTheRemoteDeletedIsProof() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.commitFile("work.txt", in: feat)
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "feat"], in: feat.path)
    _ = try await harness.git.run(["push", "-q", "origin", "--delete", "feat"], in: feat.path)
    _ = try await harness.git.run(
      ["remote", "set-url", "origin", GitHarness.gitHubOrigin],
      in: harness.project.path,
    )
    let tip = try await harness.tip(of: feat)
    host.answer(branch: "feat", .success([.sample(number: 9, state: .merged, headCommit: tip)]))

    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(harness.model.remoteState.upstreams[feat.id]?.tip == nil)
    let state = harness.model.mergeState(of: feat)
    #expect(state == .merged(.pullRequest(number: 9), into: "origin/main"))
    #expect(state.isCertain)
  }

  @Test func aFailedListKeepsWhatABranchAskedAloneFound() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    host.answer(branch: "feat", .success([.sample(number: 9, state: .merged)]))
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)
    host.answer(.failure(.failed("HTTP 502")))

    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(host.askedBranches == ["feat"])
    #expect(harness.model.services(of: feat).pullRequest?.number == 9)
  }

  @Test func aHostThatDisownsTheRepositoryDropsWhatBranchesAskedAloneFound() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    host.answer(branch: "feat", .success([.sample(number: 9, state: .merged)]))
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)
    host.answer(.failure(.notHosted))

    await harness.model.refreshServices(ofProject: harness.project.id)

    let reading = try #require(harness.model.remoteState.pullRequests[harness.project.id])
    #expect(reading.lookups.isEmpty)
    #expect(harness.model.services(of: feat).pullRequest == nil)
  }

  @Test func branchesAskedAloneAddTheirPullRequestsInBranchOrder() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    for branch in ["c", "a", "b"] {
      let worktree = try await harness.createWorktree(onBranch: branch)
      _ = try await harness.git.run(["push", "-q", "-u", "origin", branch], in: worktree.path)
    }
    host.answer(.success([.sample(number: 1, headBranch: "listed")]))
    host.answer(branch: "a", .success([.sample(number: 10, headBranch: "a")]))
    host.answer(branch: "b", .success([.sample(number: 20, headBranch: "b")]))
    host.answer(branch: "c", .success([.sample(number: 30, headBranch: "c")]))

    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    let reading = try #require(harness.model.remoteState.pullRequests[harness.project.id])
    #expect(reading.pullRequests.map(\.number) == [1, 10, 20, 30])
    #expect(host.askedBranches.sorted() == ["a", "b", "c"])
  }

  @Test func aBranchPushedUnderAnotherNameIsAskedAloneByItsNameOnTheRemote() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "feat:published"], in: feat.path)

    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(host.askedBranches == ["published"])
  }

  @Test func theTrunkIsNotAskedAlone() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    _ = try await harness.git.run(
      ["push", "-q", "-u", "origin", "main"],
      in: harness.project.path,
    )
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)

    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    let main = try #require(harness.model.workspace.worktrees(of: harness.project.id).first)
    #expect(harness.model.remoteState.upstreams[main.id]?.branch == "main")
    #expect(host.askedBranches == ["feat"])
  }

  @Test func aFailedLookupFailsTheReadAndTheRowKeepsWhatItShowed() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    host.answer(branch: "feat", .success([.sample(number: 9, state: .open)]))
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)
    host.answer(branch: "feat", .failure(.failed("HTTP 502")))

    await harness.model.refreshServices(ofProject: harness.project.id)

    let reading = try #require(harness.model.remoteState.pullRequests[harness.project.id])
    #expect(reading.failure == .failed("HTTP 502"))
    #expect(harness.model.services(of: feat).pullRequest?.number == 9)
  }

  @Test func aFailedReadKeepsWhatTheRowShowedAndSaysWhy() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    host.answer(.success([.sample(number: 9, headBranch: "feat")]))
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    host.answer(.failure(.failed("HTTP 502: Bad Gateway")))
    await harness.model.refreshServices(ofProject: harness.project.id)

    let services = harness.model.services(of: feat)
    #expect(services.pullRequest?.number == 9)
    #expect(services.readProblem?.failure == .failed("HTTP 502: Bad Gateway"))
    #expect(services.readProblem?.lastAnsweredAt != nil)
  }

  @Test func aRepositoryTheHostDisownsIsNotAskedAgainUntilItsRemotesChange() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    host.answer(.failure(.notHosted))

    await harness.model.refreshServices(ofProject: harness.project.id)
    await harness.model.refreshServices(ofProject: harness.project.id)
    #expect(host.calls == ["list"])

    _ = try await harness.git.run(
      ["remote", "add", "origin", GitHarness.gitHubOrigin],
      in: harness.project.path,
    )
    await harness.model.refreshServices(ofProject: harness.project.id)
    #expect(host.calls == ["list", "list"])
  }

  @Test func aReadLandingAfterItsProjectWasRemovedLeavesNoAnswerTime() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    defer { host.releaseHeldReads() }
    host.holdList()
    let id = harness.project.id
    let read = Task { _ = await harness.model.refreshServices(ofProject: id) }
    try await waitUntil { host.calls == ["list"] }

    harness.model.removeProject(harness.project)
    host.releaseHeldReads()
    await read.value

    #expect(harness.model.remoteState.pullRequestsAnsweredAt[id] == nil)
  }

  @Test func aReadLandingAfterItsIntegrationWasTurnedOffLeavesNoAnswerTime() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    defer { host.releaseHeldReads() }
    host.holdList()
    let id = harness.project.id
    let read = Task { _ = await harness.model.refreshServices(ofProject: id) }
    try await waitUntil { host.calls == ["list"] }

    harness.model.setIntegration(.gitHub, isEnabled: false, for: harness.project)
    host.releaseHeldReads()
    await read.value

    #expect(harness.model.remoteState.pullRequestsAnsweredAt[id] == nil)
  }

  @Test func aRepositoryTheHostDisownedIsAskedAgainOnceTheAnswerIsOld() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    host.answer(.failure(.notHosted))
    await harness.model.refreshServices(ofProject: harness.project.id)

    harness.model.remoteState.pullRequests[harness.project.id]?.notHostedSince = .distantPast
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(host.calls == ["list", "list"], "a login since may have made it the host's")
  }

  @Test func aDisownedRepositoryAskedAgainWaitsAnotherIntervalAfterTheSameAnswer() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    host.answer(.failure(.notHosted))
    await harness.model.refreshServices(ofProject: harness.project.id)
    harness.model.remoteState.pullRequests[harness.project.id]?.notHostedSince = .distantPast
    await harness.model.refreshServices(ofProject: harness.project.id)

    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(host.calls == ["list", "list"])
  }
}
