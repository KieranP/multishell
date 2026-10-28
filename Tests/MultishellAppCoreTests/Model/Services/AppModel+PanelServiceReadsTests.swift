import Foundation
import Observation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit
@testable import MultishellServices

@Suite(.serialized) @MainActor
struct AppModelPanelServiceReadsTests {
  /// A pushed `feat` with a pull request and a run, selected with the panel open.
  private func showingFeat(
    _ harness: GitHarness
  ) async throws -> (
    Worktree, FakePullRequestHost, FakeCIProvider
  ) {
    let (host, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    let tip = try await harness.tip(of: feat)
    host.answer(.success([.sample(number: 9, headBranch: "feat", headCommit: tip)]))
    provider.answer(recent: [.sample(id: "r2", branch: "feat", commit: tip, status: .failed)])
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)
    harness.model.select(feat)
    harness.model.setShowsFilesPanel(true)
    return (feat, host, provider)
  }

  @Test func theTabsRedrawOnceTheToolsAreFound() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let changed = AtomicFlag()
    withObservationTracking {
      _ = harness.model.showsPullRequestPanelPage
    } onChange: {
      changed.raise()
    }

    harness.connectServices()

    #expect(changed.raised)
  }

  @Test func turningToThePullRequestPageReadsItsChecksAndNoFileListing() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, host, _) = try await showingFeat(harness)
    let required = PullRequestCheck(
      name: "build",
      workflow: "CI",
      status: .failed,
      isRequired: true,
      link: nil,
    )
    host.answerChecks([required])

    harness.model.setFilesPanelMode(.pullRequest)
    try await waitUntil { harness.model.remoteState.checks[feat.id] != nil }

    #expect(harness.model.remoteState.checks[feat.id]?.checks == [required])
    #expect(harness.model.trackedFiles[feat.id] == nil, "a services' page lists no files")
    let pullRequest = try #require(harness.model.services(of: feat).pullRequest)
    #expect(
      harness.model.mergeReadiness(of: pullRequest, in: feat).blockers == [.failingChecks(1)]
    )
  }

  @Test func turningToTheCIPageReadsTheBranchsHistoryAndTheFailedRunsReport() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, _, provider) = try await showingFeat(harness)
    let newest = CIRun.sample(id: "r2", branch: "feat", status: .failed)
    provider.answer(recent: [newest], history: [newest, .sample(id: "r1", branch: "feat")])

    harness.model.setFilesPanelMode(.ciRuns)
    try await waitUntil { harness.model.failureReport(of: newest) != nil }

    #expect(harness.model.ciPage(of: feat) == .run(newest))
    #expect(harness.model.earlierCIRuns(of: feat).map(\.id) == ["r1"])
    #expect(
      harness.model.failureReport(of: newest)?.excerpt(ofJob: "test-macos", inWorkflow: "build")
        == "test-macos failed"
    )
    #expect(provider.calls.contains("history feat"))
    let rerun = CIRun.sample(id: "r2", branch: "feat", status: .running)
    #expect(harness.model.failureReport(of: rerun) == nil, "a rerun has it going again")
  }

  @Test func turningToTheCIPageWhileTheChecksAreReadReadsItsHistory() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, host, provider) = try await showingFeat(harness)
    defer { host.releaseHeldReads() }
    host.holdChecks()
    harness.model.setFilesPanelMode(.pullRequest)
    try await waitUntil { host.calls.contains("checks #9") }

    harness.model.setFilesPanelMode(.ciRuns)
    try await waitUntil({ provider.calls.contains("history feat") }, seconds: 3)

    #expect(provider.calls.contains("history feat"))
  }

  @Test func theCIPageListsNoRunOfAnotherRepositorysBranchOfTheSameName() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, _, provider) = try await showingFeat(harness)
    let theirs = CIRun.sample(
      id: "theirs",
      branch: "feat",
      repository: RemoteRepository(owner: "team", name: "demo"),
    )
    provider.answer(recent: [], history: [theirs])
    await harness.model.refreshServices(ofProject: harness.project.id)

    harness.model.setFilesPanelMode(.ciRuns)
    try await waitUntil { harness.model.remoteState.ciHistories[feat.id] != nil }

    #expect(harness.model.ciPage(of: feat) == .noRuns(branch: "feat"))
  }

  @Test func aToolGoneFromThePathTurnsThePanelBackToItsListedFiles() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, _, _) = try await showingFeat(harness)
    harness.model.setFilesPanelMode(.pullRequest)
    #expect(harness.model.trackedFiles[feat.id] == nil)

    await harness.model.adoptServiceTools(on: harness.root.path)
    try await waitUntil { harness.model.trackedFiles[feat.id] != nil }

    #expect(harness.model.shownFilesPanelMode == .files)
    #expect(harness.model.trackedFiles[feat.id] != nil)
  }

  @Test func theCIPageDropsTheHistoryOfABranchItNoLongerFollows() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, _, provider) = try await showingFeat(harness)
    provider.answer(recent: [], history: [.sample(id: "old", branch: "feat")])
    harness.model.setFilesPanelMode(.ciRuns)
    try await waitUntil {
      harness.model.ciPage(of: feat) == .run(.sample(id: "old", branch: "feat"))
    }

    _ = try await harness.git.run(
      ["update-ref", "refs/remotes/origin/renamed", "HEAD"],
      in: feat.path,
    )
    _ = try await harness.git.run(["branch", "-q", "-u", "origin/renamed"], in: feat.path)
    _ = try await harness.git.run(["update-ref", "-d", "refs/remotes/origin/feat"], in: feat.path)
    await harness.model.refreshBranchScan(of: harness.project)

    #expect(harness.model.ciPage(of: feat) == .noRuns(branch: "renamed"))
    #expect(harness.model.earlierCIRuns(of: feat).isEmpty)
  }

  @Test func turningBackToAPageReadMomentsAgoAsksNothing() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, host, _) = try await showingFeat(harness)
    harness.model.setFilesPanelMode(.pullRequest)
    try await waitUntil { harness.model.remoteState.checks[feat.id]?.checks != nil }

    await harness.model.readPanelServicesIfDue(of: feat)

    #expect(host.calls.filter { $0.hasPrefix("checks") } == ["checks #9"])
  }

  @Test func aServicesPageShownInTheBackgroundAsksNothing() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, host, _) = try await showingFeat(harness)
    harness.platform.isActive = false
    harness.model.setFilesPanelMode(.pullRequest)

    await harness.model.readPanelServicesIfDue(of: feat)

    #expect(!host.calls.contains { $0.hasPrefix("checks") })
  }

  @Test func anIntegrationTurnedOffTakesThePagesReadsWithIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, _, provider) = try await showingFeat(harness)
    provider.answer(recent: [], history: [.sample(id: "h1", branch: "feat")])
    harness.model.setFilesPanelMode(.pullRequest)
    try await waitUntil { harness.model.remoteState.checks[feat.id] != nil }
    harness.model.setFilesPanelMode(.ciRuns)
    try await waitUntil { harness.model.remoteState.ciHistories[feat.id] != nil }

    harness.model.setIntegration(.gitHub, isEnabled: false, for: harness.project)
    harness.model.setIntegration(.circleCI, isEnabled: false, for: harness.project)

    #expect(harness.model.remoteState.checks[feat.id] == nil)
    #expect(harness.model.remoteState.ciHistories[feat.id] == nil)
  }

  @Test func theCIPageNamesItsProviderAndProblemBeforeTheProjectsFirstRead() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "feat"], in: feat.path)
    await harness.model.refreshBranchScan(of: harness.project)
    provider.failHistory()
    harness.model.select(feat)
    harness.model.setShowsFilesPanel(true)

    harness.model.setFilesPanelMode(.ciRuns)
    try await waitUntil { harness.model.remoteState.ciHistories[feat.id] != nil }

    #expect(harness.model.ciProviderName(of: feat) == "CircleCI")
    #expect(harness.model.panelReadProblem(of: feat) != nil)
  }

  @Test func checksLandingAfterTheHostWasTurnedOffAreNotKept() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, host, _) = try await showingFeat(harness)
    defer { host.releaseHeldReads() }
    host.holdChecks()
    harness.model.setFilesPanelMode(.pullRequest)
    try await waitUntil { host.calls.contains("checks #9") }

    harness.model.setIntegration(.gitHub, isEnabled: false, for: harness.project)
    host.releaseHeldReads()
    let read = PanelRead(worktree: feat.id, page: .pullRequest)
    try await waitUntil { !harness.model.remoteState.panelReadLog.isAsking(read) }

    #expect(harness.model.remoteState.checks[feat.id] == nil)
  }

  @Test func theCIPageAsksNothingOfARepositoryWithoutTheProvidersFile() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "feat"], in: feat.path)
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)
    harness.model.select(feat)
    harness.model.setShowsFilesPanel(true)
    harness.model.setFilesPanelMode(.ciRuns)

    await harness.model.readPanelServicesIfDue(of: feat)

    #expect(harness.model.ciPage(of: feat) == .notConfigured)
    #expect(!provider.calls.contains { $0.hasPrefix("history") })
  }

  @Test func aReportReadWhileTheRunWentIsReadOnceMoreWhenItEnds() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, _, provider) = try await showingFeat(harness)
    let going = CIRun.sample(id: "r2", branch: "feat", status: .failed, isFinished: false)
    provider.answer(recent: [going], history: [going])
    await harness.model.refreshServices(ofProject: harness.project.id)
    harness.model.setFilesPanelMode(.ciRuns)
    try await waitUntil { harness.model.remoteState.failureReports["r2"] != nil }

    let ended = CIRun.sample(id: "r2", branch: "feat", status: .failed, isFinished: true)
    provider.answer(recent: [ended], history: [ended])
    await harness.model.refreshServices(ofProject: harness.project.id)
    harness.model.remoteState.panelReadLog.forget(PanelRead(worktree: feat.id, page: .ciRuns))
    await harness.model.readPanelServicesIfDue(of: feat)

    #expect(provider.calls.filter { $0 == "report r2" }.count == 2)
  }

  @Test func aRunSeenRerunningHasItsReportReadAgainOnceItFailsAgain() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, _, provider) = try await showingFeat(harness)
    let failed = CIRun.sample(id: "r2", branch: "feat", status: .failed, isFinished: true)
    provider.answer(recent: [failed], history: [failed])
    harness.model.setFilesPanelMode(.ciRuns)
    try await waitUntil { harness.model.remoteState.failureReports["r2"] != nil }
    harness.model.setFilesPanelMode(.files)

    let rerunning = CIRun.sample(id: "r2", branch: "feat", status: .running, isFinished: false)
    provider.answer(recent: [rerunning], history: [rerunning])
    await harness.model.refreshServices(ofProject: harness.project.id)
    let failedAgain = CIRun.sample(id: "r2", branch: "feat", status: .failed, isFinished: true)
    provider.answer(recent: [failedAgain], history: [failedAgain])
    await harness.model.refreshServices(ofProject: harness.project.id)
    harness.model.remoteState.panelReadLog.forget(PanelRead(worktree: feat.id, page: .ciRuns))
    harness.model.setFilesPanelMode(.ciRuns)
    await harness.model.readPanelServicesIfDue(of: feat)

    try await waitUntil { provider.calls.filter { $0 == "report r2" }.count == 2 }

    #expect(provider.calls.filter { $0 == "report r2" }.count == 2)
  }

  @Test func theCIPageAsksNothingBeforeTheProjectsReadWhereTheFileIsMissing() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "feat"], in: feat.path)
    await harness.model.refreshBranchScan(of: harness.project)
    harness.model.select(feat)
    harness.model.setShowsFilesPanel(true)
    harness.model.setFilesPanelMode(.ciRuns)

    await harness.model.readPanelServicesIfDue(of: feat)

    #expect(!provider.calls.contains { $0.hasPrefix("history") })
  }

  @Test func aMergedPullRequestsChecksAreNotReadAgain() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, host, _) = try await showingFeat(harness)
    let tip = try await harness.tip(of: feat)
    host.answer(
      .success([.sample(number: 9, state: .merged, headBranch: "feat", headCommit: tip)])
    )
    await harness.model.refreshServices(ofProject: harness.project.id)
    harness.model.setFilesPanelMode(.pullRequest)
    try await waitUntil { harness.model.remoteState.checks[feat.id]?.checks != nil }

    harness.model.remoteState.panelReadLog.forget(PanelRead(worktree: feat.id, page: .pullRequest))
    await harness.model.readPanelServicesIfDue(of: feat)

    #expect(host.calls.filter { $0.hasPrefix("checks") } == ["checks #9"])
  }

  @Test func aWorktreeThePanelLeftKeepsItsHistoryButNotItsRunsDetails() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, _, provider) = try await showingFeat(harness)
    let earlier = CIRun.sample(id: "h0", branch: "feat")
    provider.answer(recent: [], history: [.sample(id: "h1", branch: "feat"), earlier])
    harness.model.setFilesPanelMode(.ciRuns)
    try await waitUntil { harness.model.remoteState.ciHistories[feat.id] != nil }
    await harness.model.readCIRunDetails(of: earlier, for: feat)
    let main = try #require(harness.worktree(onBranch: "main"))

    harness.model.select(main)
    await harness.model.readPanelServicesIfDue(of: main)
    harness.model.select(feat)
    await harness.model.readPanelServicesIfDue(of: feat)

    #expect(provider.calls.filter { $0 == "history feat" } == ["history feat"])
    #expect(harness.model.remoteState.ciWorkflows["h0"] == nil, "an earlier run's details go")
  }

  @Test func rowsPassedQuicklyOnAServicesPageReadOnlyTheOneTheSelectionRestsOn() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, host, _) = try await showingFeat(harness)
    let main = try #require(harness.worktree(onBranch: "main"))
    host.answer(.success([.sample(number: 9, headBranch: "feat")]))
    await harness.model.refreshServices(ofProject: harness.project.id)
    harness.model.select(main)
    harness.model.setFilesPanelMode(.pullRequest)

    harness.model.select(feat)
    harness.model.readFilesPanel(of: feat.id)
    harness.model.select(main)
    harness.model.readFilesPanel(of: main.id)
    let mainRead = PanelRead(worktree: main.id, page: .pullRequest)
    try await waitUntil {
      let log = harness.model.remoteState.panelReadLog
      return log.hasAsked(mainRead) && !log.isAsking(mainRead)
    }

    #expect(!host.calls.contains("checks #9"), "feat was passed, not stopped on")
  }

  @Test func aCIPageWithNoHistoryToKeepIsNotReadEveryTick() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "feat"], in: feat.path)
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)
    harness.model.select(feat)
    harness.model.setShowsFilesPanel(true)
    harness.model.setFilesPanelMode(.ciRuns)
    await harness.model.readPanelServicesIfDue(of: feat)

    #expect(!harness.model.panelReadingIsStale(feat))
    #expect(!provider.calls.contains { $0.hasPrefix("history") })
  }

  @Test func checksReadForAnotherPullRequestOnTheSameHeadAreStale() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, host, _) = try await showingFeat(harness)
    let tip = try await harness.tip(of: feat)
    harness.model.remoteState.checks[feat.id] = PullRequestChecks(
      pullRequestNumber: 5,
      headCommit: tip,
      checks: [],
    )
    host.answer(.success([.sample(number: 6, headBranch: "feat", headCommit: tip)]))
    await harness.model.refreshServices(ofProject: harness.project.id)
    harness.model.setFilesPanelMode(.pullRequest)

    #expect(harness.model.panelReadingIsStale(feat))
  }

  @Test func thePollReadsThePagesChecksOnlyWhileThePageShows() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, host, _) = try await showingFeat(harness)

    await harness.model.pollPanelServices()
    #expect(!host.calls.contains("checks #9"), "Files shows, so nothing is asked")

    harness.model.setShowsFilesPanel(false)
    harness.store.setFilesPanelMode(.pullRequest)
    await harness.model.pollPanelServices()
    #expect(!host.calls.contains("checks #9"), "the panel is shut")
  }

  @Test func aFailedHistoryReadWaitsItsIntervalRatherThanEveryTick() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, _, provider) = try await showingFeat(harness)
    provider.failHistory()
    harness.model.setFilesPanelMode(.ciRuns)
    try await waitUntil { provider.calls.contains("history feat") }

    await harness.model.pollPanelServices()
    await harness.model.pollPanelServices()

    #expect(provider.calls.filter { $0 == "history feat" }.count == 1)
  }

  @Test func aGitChangeWhileAServicesPageShowsReadsNoFileListing() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, _, _) = try await showingFeat(harness)
    harness.model.setFilesPanelMode(.pullRequest)
    let common = try await harness.model.coordinator?.git.commonGitDirectory(harness.project)
    let targets = FileChangeTargets(
      changed: [try #require(common).appendingPathComponent("index")],
      projects: [harness.project],
      gitDirectories: [harness.project.id: try #require(common)],
      worktrees: harness.model.workspace.worktrees,
      themesDirectory: harness.model.themesDirectory,
    )

    harness.model.noteFilesPanelChanges(targets)

    #expect(harness.model.pendingTrackedFilesReads[feat.id] == nil)
  }

  @Test func aServicesPageFallenBackToFilesOpensFolders() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.store.setFilesPanelMode(.pullRequest)
    let main = try #require(harness.worktree(onBranch: "main"))

    #expect(
      harness.model.filesPanelState(of: main.id).mode == .files,
      "no host's tool, so Files shows",
    )
  }
}
