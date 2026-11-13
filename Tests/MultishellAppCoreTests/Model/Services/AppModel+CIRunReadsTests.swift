import Foundation
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit
@testable import MultishellServices

@Suite(.serialized) @MainActor
struct AppModelCIRunReadsTests {
  @Test func aRepositoryWithoutTheProvidersFileIsNeverAskedAboutRuns() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()

    await harness.model.refreshServices(ofProject: harness.project.id)
    #expect(provider.calls.isEmpty)
    #expect(
      harness.model.integrationRepositoryFit(.circleCI, for: harness.project) == .notConfigured
    )

    try harness.writeCIConfiguration()
    await harness.model.refreshServices(ofProject: harness.project.id)
    #expect(provider.calls == ["recent"])
    #expect(harness.model.integrationRepositoryFit(.circleCI, for: harness.project) == .unknown)
  }

  @Test func aShownBranchTheRecentRunsLeftOutIsAskedAloneUntilItIsPushedTo() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    await harness.model.refreshBranchScan(of: harness.project)
    let tip = try #require(harness.model.remoteState.upstreams[feat.id]?.tip)
    provider.answer(
      recent: [],
      byBranch: ["feat": .sample(id: "old", branch: "feat", commit: tip)],
    )

    await harness.model.refreshServices(ofProject: harness.project.id)
    #expect(harness.model.services(of: feat).ciRun?.id == "old")
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(provider.calls.filter { $0 == "branch feat" } == ["branch feat"])
  }

  @Test func aBranchAskedAloneBeforeItsPushedTipRanIsAskedAgainUntilThatRunAppears() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    await harness.model.refreshBranchScan(of: harness.project)
    let tip = try #require(harness.model.remoteState.upstreams[feat.id]?.tip)
    let before = CIRun.sample(id: "before", branch: "feat", commit: "0000000", status: .failed)
    provider.answer(recent: [], byBranch: ["feat": before])
    await harness.model.refreshServices(ofProject: harness.project.id)

    provider.answer(
      recent: [],
      byBranch: ["feat": .sample(id: "fix", branch: "feat", commit: tip)],
    )
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(harness.model.services(of: feat).ciRun?.id == "fix")
  }

  @Test func aRunOfThePushedTipNamedByItsSevenCharactersEndsTheWait() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    await harness.model.refreshBranchScan(of: harness.project)
    let tip = try #require(harness.model.remoteState.upstreams[feat.id]?.tip)
    let run = CIRun.sample(id: "fix", branch: "feat", commit: String(tip.prefix(7)))
    provider.answer(recent: [], byBranch: ["feat": run])
    await harness.model.refreshServices(ofProject: harness.project.id)

    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(provider.calls.filter { $0 == "branch feat" } == ["branch feat"])
  }

  @Test func aBranchAskedAloneBeforeItsFirstRunIsAskedAgainUntilThatRunAppears() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    await harness.model.refreshBranchScan(of: harness.project)
    let tip = try #require(harness.model.remoteState.upstreams[feat.id]?.tip)
    provider.answer(recent: [])
    await harness.model.refreshServices(ofProject: harness.project.id)

    provider.answer(
      recent: [],
      byBranch: ["feat": .sample(id: "first", branch: "feat", commit: tip)],
    )
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(harness.model.services(of: feat).ciRun?.id == "first")
  }

  @Test func askingABranchAgainAtTheSameTipKeepsWhenThatTipWasFirstAsked() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    await harness.model.refreshBranchScan(of: harness.project)
    provider.answer(recent: [])
    await harness.model.refreshServices(ofProject: harness.project.id)
    let lookups = { harness.model.remoteState.ciRuns[harness.project.id]?.lookups }
    let firstAsked = try #require(lookups()?["feat"]?.tipAskedSince)

    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(provider.calls.filter { $0 == "branch feat" }.count == 2)
    #expect(lookups()?["feat"]?.tipAskedSince == firstAsked)
  }

  @Test func aPushedTipWithNoRunIsNotAskedAgainOnceItHasHadTimeToRun() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    await harness.model.refreshBranchScan(of: harness.project)
    let tip = try #require(harness.model.remoteState.upstreams[feat.id]?.tip)
    provider.answer(recent: [])
    await harness.model.refreshServices(ofProject: harness.project.id)
    harness.model.remoteState.ciRuns[harness.project.id]?.lookups["feat"] = BranchRunLookup(
      upstreamTip: tip,
      run: nil,
      tipAskedSince: .distantPast,
    )

    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(provider.calls.filter { $0 == "branch feat" }.count == 1)
  }

  @Test func aNewerRunOfUnknownStatusInTheRecentRunsIsShownOverTheFailureBeforeIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    await harness.model.refreshBranchScan(of: harness.project)
    provider.answer(recent: [
      .sample(id: "new", branch: "feat", status: .unknown),
      .sample(id: "old", branch: "feat", status: .failed),
    ])

    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(harness.model.services(of: feat).ciRun?.id == "new")
    #expect(harness.model.services(of: feat).ciRun?.status == .unknown)
  }

  @Test func aBranchAskedAloneWhoseRunIsOfUnknownStatusIsAskedAgainEachRound() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    await harness.model.refreshBranchScan(of: harness.project)
    let tip = try #require(harness.model.remoteState.upstreams[feat.id]?.tip)
    let unknown = CIRun.sample(id: "r", branch: "feat", commit: tip, status: .unknown)
    provider.answer(recent: [], byBranch: ["feat": unknown])
    await harness.model.refreshServices(ofProject: harness.project.id)
    let ended = CIRun.sample(id: "r", branch: "feat", commit: tip, status: .passed)
    provider.answer(recent: [], byBranch: ["feat": ended])

    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(harness.model.services(of: feat).ciRun?.status == .passed)
  }

  @Test func aPushDuringTheWaitStartsTheWaitAgainForTheNewTip() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "feat"], in: feat.path)
    await harness.model.refreshBranchScan(of: harness.project)
    provider.answer(recent: [])
    await harness.model.refreshServices(ofProject: harness.project.id)
    let lookup = { harness.model.remoteState.ciRuns[harness.project.id]?.lookups["feat"] }
    let firstAsked = try #require(lookup()?.tipAskedSince)

    _ = try await harness.git.run(["commit", "-q", "--allow-empty", "-m", "fix"], in: feat.path)
    _ = try await harness.git.run(["push", "-q", "origin", "feat"], in: feat.path)
    await harness.model.refreshBranchScan(of: harness.project)
    let newTip = try #require(harness.model.remoteState.upstreams[feat.id]?.tip)
    await harness.model.refreshServices(ofProject: harness.project.id)
    try await waitUntil({ lookup()?.upstreamTip == newTip }, seconds: 5)

    #expect(try #require(lookup()?.tipAskedSince) > firstAsked)
  }

  @Test func aLookupFailingDuringTheWaitKeepsWhenTheTipWasFirstAsked() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    await harness.model.refreshBranchScan(of: harness.project)
    provider.answer(recent: [])
    await harness.model.refreshServices(ofProject: harness.project.id)
    let lookup = { harness.model.remoteState.ciRuns[harness.project.id]?.lookups["feat"] }
    let firstAsked = try #require(lookup()?.tipAskedSince)
    provider.failLookUp(ofBranch: "feat")
    await harness.model.refreshServices(ofProject: harness.project.id)
    provider.answerLookUp(ofBranch: "feat")

    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(provider.calls.filter { $0 == "branch feat" }.count == 3)
    #expect(lookup()?.tipAskedSince == firstAsked)
  }

  @Test func oneBranchFailingToAnswerKeepsItsRunAndTakesTheOthersNewOnes() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    let fix = try await harness.createWorktree(onBranch: "fix")
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "fix"], in: fix.path)
    try await harness.pushToGitHubOrigin(feat)
    await harness.model.refreshBranchScan(of: harness.project)
    provider.answer(
      recent: [],
      byBranch: [
        "feat": .sample(id: "feat-1", branch: "feat", status: .running),
        "fix": .sample(id: "fix-1", branch: "fix", status: .running),
      ],
    )
    await harness.model.refreshServices(ofProject: harness.project.id)

    provider.answer(
      recent: [],
      byBranch: ["feat": .sample(id: "feat-2", branch: "feat")],
    )
    provider.failLookUp(ofBranch: "fix")
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(harness.model.services(of: feat).ciRun?.id == "feat-2")
    #expect(harness.model.services(of: fix).ciRun?.id == "fix-1")
  }

  @Test func aBranchFailingToAnswerAloneKeepsTheRunTheRecentRunsGaveIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    await harness.model.refreshBranchScan(of: harness.project)
    provider.answer(recent: [.sample(id: "feat-1", branch: "feat")])
    await harness.model.refreshServices(ofProject: harness.project.id)

    provider.answer(recent: [])
    provider.failLookUp(ofBranch: "feat")
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(harness.model.services(of: feat).ciRun?.id == "feat-1")
  }

  @Test func aBranchHiddenForARoundIsNotAskedAloneAgainWhenItReturns() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "feat"], in: feat.path)
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    await harness.model.refreshBranchScan(of: harness.project)
    let tip = try #require(harness.model.remoteState.upstreams[feat.id]?.tip)
    provider.answer(
      recent: [],
      byBranch: ["feat": .sample(id: "old", branch: "feat", commit: tip)],
    )
    await harness.model.refreshServices(ofProject: harness.project.id)

    harness.model.sidebarFilterText = "main"
    await harness.model.refreshServices(ofProject: harness.project.id)
    #expect(harness.model.services(of: feat).ciRun?.id == "old", "hidden, it keeps its run")
    harness.model.sidebarFilterText = ""
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(provider.calls.filter { $0 == "branch feat" } == ["branch feat"])
  }

  @Test func aLookupMadeBeforeTheRunExistedIsNotBroughtBackOnceTheRecentRunsDropIt()
    async throws
  {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    await harness.model.refreshBranchScan(of: harness.project)
    provider.answer(recent: [])
    await harness.model.refreshServices(ofProject: harness.project.id)
    let first = CIRun.sample(id: "r1", branch: "feat")
    provider.answer(recent: [first], byBranch: ["feat": first])
    await harness.model.refreshServices(ofProject: harness.project.id)

    provider.answer(recent: [], byBranch: ["feat": first])
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(harness.model.services(of: feat).ciRun?.id == "r1")
  }

  @Test func aFailedLookupKeepsTheRunTheRowShowedOverAnOlderLookup() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "feat"], in: feat.path)
    await harness.model.refreshBranchScan(of: harness.project)
    provider.answer(
      recent: [],
      byBranch: ["feat": .sample(id: "r1", branch: "feat", status: .running)],
    )
    await harness.model.refreshServices(ofProject: harness.project.id)
    harness.model.remoteState.ciRuns[harness.project.id]?.lookups["feat"] =
      BranchRunLookup(upstreamTip: "older", run: nil, tipAskedSince: .now)

    provider.failLookUp(ofBranch: "feat")
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(harness.model.services(of: feat).ciRun?.id == "r1")
  }

  @Test func aBranchFailingToAnswerAloneIsTheOnlyRowSaidToBeOld() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    let fix = try await harness.createWorktree(onBranch: "fix")
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "feat"], in: feat.path)
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "fix"], in: fix.path)
    await harness.model.refreshBranchScan(of: harness.project)
    provider.answer(recent: [], byBranch: ["feat": .sample(id: "f", branch: "feat")])
    provider.failLookUp(ofBranch: "fix")

    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(harness.model.services(of: feat).readProblem == nil)
    #expect(harness.model.services(of: fix).readProblem?.lastAnsweredAt == nil)
    #expect(harness.model.services(of: fix).readProblem?.failure == .failed("offline"))
  }

  @Test func aProviderThatDisownsTheRepositoryTakesItsRunsOffTheRows() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    await harness.model.refreshBranchScan(of: harness.project)
    provider.answer(recent: [.sample(id: "r1", branch: "feat")])
    await harness.model.refreshServices(ofProject: harness.project.id)

    provider.failRecent(.notHosted)
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(harness.model.services(of: feat).ciRun == nil)
  }

  @Test func aBranchWhoseRemoteBranchIsGoneIsNotAskedAlone() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "feat"], in: feat.path)
    _ = try await harness.git.run(["push", "-q", "origin", "--delete", "feat"], in: feat.path)
    await harness.model.refreshBranchScan(of: harness.project)

    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(!provider.calls.contains("branch feat"))
  }

  @Test func aRunKeptForABranchTheRemoteHasSinceDeletedStopsStanding() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "feat"], in: feat.path)
    await harness.model.refreshBranchScan(of: harness.project)
    let tip = try #require(harness.model.remoteState.upstreams[feat.id]?.tip)
    provider.answer(
      recent: [],
      byBranch: ["feat": .sample(id: "r", branch: "feat", commit: tip, status: .running)],
    )
    await harness.model.refreshServices(ofProject: harness.project.id)
    try #require(harness.model.services(of: feat).ciRun?.isUnderWay == true)
    _ = try await harness.git.run(["push", "-q", "origin", "--delete", "feat"], in: feat.path)
    await harness.model.refreshBranchScan(of: harness.project)

    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(harness.model.services(of: feat).ciRun?.isUnderWay != true)
  }

  @Test func aBranchsKeptLookupIsNotRedatedByARoundThatDidNotAskIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "feat"], in: feat.path)
    await harness.model.refreshBranchScan(of: harness.project)
    let tip = try #require(harness.model.remoteState.upstreams[feat.id]?.tip)
    provider.answer(
      recent: [],
      byBranch: ["feat": .sample(id: "old", branch: "feat", commit: tip)],
    )
    await harness.model.refreshServices(ofProject: harness.project.id)
    harness.model.remoteState.ciBranchesAnsweredAt[harness.project.id]?["feat"] = .distantPast

    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(
      harness.model.remoteState.ciBranchesAnsweredAt[harness.project.id]?["feat"] == .distantPast
    )
  }

  @Test func branchAnswerTimesAreKeptOnlyForBranchesAWorktreeFollows() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "feat"], in: feat.path)
    await harness.model.refreshBranchScan(of: harness.project)
    provider.answer(recent: [
      .sample(id: "a", branch: "feat"), .sample(id: "b", branch: "someone-else"),
    ])

    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(
      harness.model.remoteState.ciBranchesAnsweredAt[harness.project.id]?.keys.sorted()
        == ["feat", "main"],
      "main's checkout follows origin/main",
    )
  }

  @Test func aRepositoryTheProviderDisownsIsNotAskedAgainUntilTheAnswerIsOld() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    provider.failRecent(.notHosted)
    await harness.model.refreshServices(ofProject: harness.project.id)

    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(provider.calls == ["recent"])
    harness.model.remoteState.ciRuns[harness.project.id]?.notHostedSince = .distantPast
    await harness.model.refreshServices(ofProject: harness.project.id)
    #expect(provider.calls == ["recent", "recent"])
  }
}
