import Foundation
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit
@testable import MultishellProcess

@Suite(.serialized) @MainActor
struct AppModelAutoRenameTests {
  private final class Requests: @unchecked Sendable {
    private let lock = NSLock()
    private var list: [OneShotRequest] = []

    var all: [OneShotRequest] { lock.withLock { list } }

    func append(_ request: OneShotRequest) {
      lock.withLock { list.append(request) }
    }
  }

  private static let claude = URL(fileURLWithPath: "/opt/fake/bin/claude")

  nonisolated private static func output(
    _ text: String,
    status: Int32 = 0,
    error: String = "",
    stop: ProcessStopReason? = nil,
  ) -> ProcessOutput {
    ProcessOutput(
      standardOutputBytes: Data(text.utf8),
      standardError: error,
      status: status,
      stopReason: stop,
    )
  }

  private static func committedFeature(
    in harness: GitHarness,
    answering reply: ProcessOutput,
    requests: Requests = Requests(),
  ) async throws -> Worktree {
    let feature = try await harness.featureInGitList()
    try await TestRepository.commit(
      "Add CSV export for billing",
      files: ["export.txt": "csv\n"],
      in: feature.path,
      using: harness.git,
    )
    await harness.model.refreshBranchScan(of: harness.project)
    harness.model.agentDetection = AgentDetection(found: ["claude": claude])
    harness.model.setPreferredAgent("claude")
    harness.model.oneShotRunner.run = { request in
      requests.append(request)
      return reply
    }
    return feature
  }

  private static func holdRuns(
    in harness: GitHarness,
    until gate: URL,
    requests: Requests,
    answering reply: ProcessOutput,
  ) {
    harness.model.oneShotRunner.run = { request in
      requests.append(request)
      while !FileManager.default.fileExists(atPath: gate.path), !request.stopper.isStopRequested {
        try await Task.sleep(for: .milliseconds(20))
      }
      return reply
    }
  }

  private static func awaitEnd(of feature: Worktree, in harness: GitHarness) async throws {
    try await waitUntil { !harness.model.isAutoRenaming(feature.id) }
  }

  @Test func theAgentsReplyNamesTheRowAndTheBranchKeepsItsName() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let requests = Requests()
    let feature = try await Self.committedFeature(
      in: harness,
      answering: Self.output("\"Billing export\"\n"),
      requests: requests,
    )

    harness.model.autoRename(feature)
    try await Self.awaitEnd(of: feature, in: harness)

    #expect(harness.model.customName(of: feature) == "Billing export")
    #expect(try await harness.branches().contains("feature"))
    #expect(harness.model.autoRenameFailure(of: feature.id) == nil)
    let request = try #require(requests.all.first)
    #expect(request.executable == Self.claude)
    #expect(request.directory.standardizedFileURL == feature.path.standardizedFileURL)
    #expect(request.arguments.first == "-p")
    #expect(request.arguments.last?.contains("- Add CSV export for billing") == true)
    #expect(request.environment[SessionEnvironment.socketVariable] == "/dev/null")
    #expect(request.environment[SessionEnvironment.sessionVariable] == "")
  }

  @Test func theRenameAgentRunsAtItsChosenModelAndEffort() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let requests = Requests()
    let feature = try await Self.committedFeature(
      in: harness,
      answering: Self.output("Billing export"),
      requests: requests,
    )
    harness.model.setRenameAgent("claude")
    harness.model.setRenameModel("haiku")
    harness.model.setRenameEffort("low")

    harness.model.autoRename(feature)
    try await Self.awaitEnd(of: feature, in: harness)

    let arguments = try #require(requests.all.first).arguments
    #expect(arguments.contains("--model") && arguments.contains("haiku"))
    #expect(arguments.contains("--effort") && arguments.contains("low"))
  }

  @Test func whileTheAgentRunsTheRowSaysSoAndASecondAutoRenameIsRefused() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let requests = Requests()
    let feature = try await Self.committedFeature(
      in: harness,
      answering: Self.output("Billing export"),
      requests: requests,
    )
    let gate = Scratch.path("auto-rename-gate")
    defer { Scratch.remove(gate) }
    Self.holdRuns(
      in: harness,
      until: gate,
      requests: requests,
      answering: Self.output("Billing export"),
    )

    harness.model.autoRename(feature)
    #expect(harness.model.isAutoRenaming(feature.id))
    #expect(!harness.model.canAutoRename(feature))
    harness.model.autoRename(feature)
    try await waitUntil { !requests.all.isEmpty }
    FileManager.default.createFile(atPath: gate.path, contents: nil)
    try await Self.awaitEnd(of: feature, in: harness)

    #expect(requests.all.count == 1)
    #expect(harness.model.canAutoRename(feature), "free again once it ends")
  }

  @Test func aFailureLeavesTheNameAndSaysWhyOnTheRowAndInABannerWhileTheAppIsBehind() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await Self.committedFeature(
      in: harness,
      answering: Self.output("", status: 1, error: "Not logged in. Run claude /login."),
    )
    harness.model.renameWorktree(feature.id, to: "Mine")
    harness.store.setNotificationPreference(NotificationPreference(notifiesOnFailure: true))
    harness.platform.isActive = false

    harness.model.autoRename(feature)
    try await Self.awaitEnd(of: feature, in: harness)

    #expect(harness.model.customName(of: feature) == "Mine")
    let failure = try #require(harness.model.autoRenameFailure(of: feature.id))
    #expect(failure.contains("Not logged in. Run claude /login."))
    let banner = try #require(harness.notifier.posted.last)
    #expect(banner.title.contains("Mine") && banner.body == failure)
    #expect(banner.key == .worktree(feature.id), "a click selects the row")

    harness.model.clearAutoRenameFailure(of: feature.id)
    #expect(harness.model.autoRenameFailure(of: feature.id) == nil)
  }

  @Test func withFailedBannersOffAFailureShowsOnlyOnTheRow() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await Self.committedFeature(
      in: harness,
      answering: Self.output("", status: 2),
    )

    harness.model.autoRename(feature)
    try await Self.awaitEnd(of: feature, in: harness)

    #expect(harness.model.autoRenameFailure(of: feature.id)?.contains("exit status 2") == true)
    #expect(harness.notifier.posted.isEmpty)
  }

  @Test func anAgentThatTimesOutSaysHowLongItWasGiven() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await Self.committedFeature(
      in: harness,
      answering: Self.output("", status: 1, stop: .timedOut(after: .seconds(90))),
    )

    harness.model.autoRename(feature)
    try await Self.awaitEnd(of: feature, in: harness)

    #expect(harness.model.autoRenameFailure(of: feature.id)?.contains("90 seconds") == true)
  }

  @Test func aReplyWithNoWordsNamesNothing() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await Self.committedFeature(in: harness, answering: Self.output("\n\"\"\n"))

    harness.model.autoRename(feature)
    try await Self.awaitEnd(of: feature, in: harness)

    #expect(harness.model.customName(of: feature) == nil)
    #expect(harness.model.autoRenameFailure(of: feature.id)?.contains("no name") == true)
  }

  @Test func anAgentDetectionDidNotFindFailsWithoutRunningAnything() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let requests = Requests()
    let feature = try await Self.committedFeature(
      in: harness,
      answering: Self.output("Billing export"),
      requests: requests,
    )
    harness.model.agentDetection = AgentDetection(found: [:])
    harness.model.loginEnvironment = LoginShellEnvironment(
      variables: [:],
      source: .processFallback(reason: "test"),
    )

    harness.model.autoRename(feature)

    #expect(harness.model.autoRenameFailure(of: feature.id)?.contains("not on your PATH") == true)
    #expect(requests.all.isEmpty)
  }

  @Test func aNewBranchWithNothingCommittedOrStagedCannotBeAutoRenamed() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureInGitList()
    harness.model.agentDetection = AgentDetection(found: ["claude": Self.claude])
    harness.model.setPreferredAgent("claude")
    try "unstaged\n".write(
      to: feature.path.appending(path: "README.md"),
      atomically: true,
      encoding: .utf8,
    )
    await harness.model.refreshStatuses()
    try await harness.statusReadsSettle(feature)

    #expect(!harness.model.canAutoRename(feature), "unstaged work is not read")

    _ = try await harness.git.run(["add", "README.md"], in: feature.path)
    await harness.model.refreshStatuses()
    try await waitUntil { harness.model.canAutoRename(feature) }
    #expect(harness.model.canAutoRename(feature), "staged work is")
  }

  @Test func aCustomCommandAsTheOnlyAgentLeavesNothingToRun() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await Self.committedFeature(in: harness, answering: Self.output("x"))
    harness.model.setPreferredAgent(AgentCatalogue.customID)

    #expect(!harness.model.canAutoRename(feature))
    harness.model.setRenameAgent("claude")
    #expect(harness.model.canAutoRename(feature), "a Rename agent stands in for it")
  }

  @Test func aNameGivenWhileTheAgentRanIsKept() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let requests = Requests()
    let feature = try await Self.committedFeature(
      in: harness,
      answering: Self.output("x"),
      requests: requests,
    )
    let gate = Scratch.path("auto-rename-kept-gate")
    defer { Scratch.remove(gate) }
    Self.holdRuns(in: harness, until: gate, requests: requests, answering: Self.output("Agent's"))

    harness.model.autoRename(feature)
    try await waitUntil { !requests.all.isEmpty }
    harness.model.renameWorktree(feature.id, to: "Mine")
    FileManager.default.createFile(atPath: gate.path, contents: nil)
    try await Self.awaitEnd(of: feature, in: harness)

    #expect(harness.model.customName(of: feature) == "Mine")
    #expect(harness.model.autoRenames[feature.id] == nil)
  }

  @Test func aRenameFieldOpenWhenTheReplyLandsStaysOpenAndUnnamed() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let requests = Requests()
    let feature = try await Self.committedFeature(
      in: harness,
      answering: Self.output("x"),
      requests: requests,
    )
    let gate = Scratch.path("auto-rename-field-gate")
    defer { Scratch.remove(gate) }
    Self.holdRuns(in: harness, until: gate, requests: requests, answering: Self.output("Agent's"))

    harness.model.autoRename(feature)
    try await waitUntil { !requests.all.isEmpty }
    harness.model.beginRenamingWorktree(feature)
    FileManager.default.createFile(atPath: gate.path, contents: nil)
    try await Self.awaitEnd(of: feature, in: harness)

    #expect(harness.model.renamingWorktreeID == feature.id)
    #expect(harness.model.customName(of: feature) == nil)
  }

  @Test func aCheckoutWhileTheAgentRanNamesNothing() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let requests = Requests()
    let feature = try await Self.committedFeature(
      in: harness,
      answering: Self.output("x"),
      requests: requests,
    )
    let gate = Scratch.path("auto-rename-checkout-gate")
    defer { Scratch.remove(gate) }
    Self.holdRuns(in: harness, until: gate, requests: requests, answering: Self.output("Agent's"))

    harness.model.autoRename(feature)
    try await waitUntil { !requests.all.isEmpty }
    _ = try await harness.git.run(["checkout", "-q", "-b", "other"], in: feature.path)
    await harness.model.refreshWorktrees(of: harness.project)
    try #require(harness.model.workspace.worktree(feature.id)?.branch == "other")
    FileManager.default.createFile(atPath: gate.path, contents: nil)
    try await Self.awaitEnd(of: feature, in: harness)

    #expect(harness.model.customName(of: feature) == nil)
    #expect(harness.model.autoRenames[feature.id] == nil)
  }

  @Test func noBannerIsPostedForTheRowInViewWithTheAppInFront() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await Self.committedFeature(
      in: harness,
      answering: Self.output("", status: 1),
    )
    harness.store.setNotificationPreference(NotificationPreference(notifiesOnFailure: true))
    try #require(harness.model.worktreeIDInView == feature.id)

    harness.model.autoRename(feature)
    try await Self.awaitEnd(of: feature, in: harness)

    #expect(harness.model.autoRenameFailure(of: feature.id) != nil)
    #expect(harness.notifier.posted.isEmpty)
  }

  @Test func clearingTheWarningTakesTheBannerBack() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await Self.committedFeature(
      in: harness,
      answering: Self.output("", status: 1),
    )
    harness.store.setNotificationPreference(NotificationPreference(notifiesOnFailure: true))
    harness.platform.isActive = false

    harness.model.autoRename(feature)
    try await Self.awaitEnd(of: feature, in: harness)
    try #require(harness.notifier.posted.count == 1)
    harness.model.clearAutoRenameFailure(of: feature.id)

    #expect(harness.notifier.withdrawn == [.worktree(feature.id)])
  }

  @Test func theMainWorktreeAtItsBaseWithNothingStagedCannotBeAutoRenamed() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    await harness.model.refreshBranchScan(of: harness.project)
    harness.model.agentDetection = AgentDetection(found: ["claude": Self.claude])
    harness.model.setPreferredAgent("claude")
    let main = try #require(harness.model.workspace.worktrees(of: harness.project.id).first)
    await harness.model.refreshStatuses()
    try await harness.statusReadsSettle(main)

    #expect(!harness.model.canAutoRename(main))
  }

  @Test func aBranchSharingNoHistoryWithItsBaseSaysSo() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await Self.committedFeature(in: harness, answering: Self.output("x"))
    _ = try await harness.git.run(["checkout", "-q", "--orphan", "fresh"], in: feature.path)
    try await TestRepository.commit(
      "Start over",
      files: ["new.txt": "new\n"],
      in: feature.path,
      using: harness.git,
    )

    await harness.model.refreshWorktrees(of: harness.project)
    let fresh = try #require(harness.model.workspace.worktree(feature.id))
    try #require(fresh.branch == "fresh")

    harness.model.autoRename(fresh)
    try await Self.awaitEnd(of: feature, in: harness)

    #expect(harness.model.autoRenameFailure(of: feature.id)?.contains("no history") == true)
  }

  @Test func aCommitOnABranchAtItsBaseEnablesAutoRenameOnceItsRefIsScanned() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureInGitList()
    harness.model.agentDetection = AgentDetection(found: ["claude": Self.claude])
    harness.model.setPreferredAgent("claude")
    await harness.model.refreshStatuses()
    try await harness.statusReadsSettle(feature)
    try #require(!harness.model.canAutoRename(feature))

    try await TestRepository.commit(
      "Add export",
      files: ["export.txt": "csv\n"],
      in: feature.path,
      using: harness.git,
    )
    await harness.model.refreshBranchScan(of: harness.project)

    #expect(harness.model.canAutoRename(feature))
  }

  @Test func beforeTheLoginShellHasAnsweredARunSaysTheAgentIsStillBeingLookedFor() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await Self.committedFeature(in: harness, answering: Self.output("x"))
    harness.model.agentDetection = AgentDetection(found: [:])
    harness.model.loginEnvironment = nil

    harness.model.autoRename(feature)

    #expect(harness.model.autoRenameFailure(of: feature.id)?.contains("still") == true)
  }

  @Test func theFailureShownIsTheEndOfWhatTheAgentSaid() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let preamble = (1...20).map { "banner line \($0) with workdir and model" }.joined(
      separator: "\n"
    )
    let feature = try await Self.committedFeature(
      in: harness,
      answering: Self.output("", status: 1, error: preamble + "\nError: not logged in"),
    )

    harness.model.autoRename(feature)
    try await Self.awaitEnd(of: feature, in: harness)

    let failure = try #require(harness.model.autoRenameFailure(of: feature.id))
    #expect(failure.contains("not logged in"))
    #expect(!failure.contains("banner line 1 "), "the start of a long preamble is cut")
  }

  @Test func aNewRunTakesBackTheLastFailuresBanner() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let requests = Requests()
    let feature = try await Self.committedFeature(
      in: harness,
      answering: Self.output("", status: 1),
      requests: requests,
    )
    harness.store.setNotificationPreference(NotificationPreference(notifiesOnFailure: true))
    harness.platform.isActive = false
    harness.model.autoRename(feature)
    try await Self.awaitEnd(of: feature, in: harness)
    try #require(harness.notifier.posted.count == 1)
    harness.model.oneShotRunner.run = { _ in Self.output("Billing export") }

    harness.model.autoRename(feature)
    try await Self.awaitEnd(of: feature, in: harness)

    #expect(harness.notifier.withdrawn == [.worktree(feature.id)])
    #expect(harness.model.customName(of: feature) == "Billing export")
  }

  @Test func forgettingTheWorktreeStopsItsAgent() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let requests = Requests()
    let feature = try await Self.committedFeature(
      in: harness,
      answering: Self.output("x"),
      requests: requests,
    )
    let gate = Scratch.path("auto-rename-stop-gate")
    defer { Scratch.remove(gate) }
    Self.holdRuns(in: harness, until: gate, requests: requests, answering: Self.output("x"))

    harness.model.autoRename(feature)
    try await waitUntil { !requests.all.isEmpty }
    harness.model.forgetWorktrees([feature.id])

    #expect(try #require(requests.all.first).stopper.isStopRequested)
    FileManager.default.createFile(atPath: gate.path, contents: nil)
  }

  @Test func forgettingAWorktreeTakesBackItsFailureBanner() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await Self.committedFeature(
      in: harness,
      answering: Self.output("", status: 1),
    )
    harness.store.setNotificationPreference(NotificationPreference(notifiesOnFailure: true))
    harness.platform.isActive = false
    harness.model.autoRename(feature)
    try await Self.awaitEnd(of: feature, in: harness)
    try #require(harness.notifier.posted.count == 1)

    harness.model.forgetWorktrees([feature.id])

    #expect(harness.notifier.withdrawn == [.worktree(feature.id)])
  }

  @Test func theBannerNamesTheProjectAsAnAgentsDoes() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await Self.committedFeature(
      in: harness,
      answering: Self.output("", status: 1),
    )
    harness.store.setNotificationPreference(NotificationPreference(notifiesOnFailure: true))
    harness.platform.isActive = false

    harness.model.autoRename(feature)
    try await Self.awaitEnd(of: feature, in: harness)

    #expect(harness.notifier.posted.last?.title.contains(harness.project.name) == true)
  }

  @Test func aBareRepositorysRowCannotBeAutoRenamed() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (bare, checkout) = try await TestRepository.bareClone(
      of: harness.project.path,
      in: harness.root,
      worktree: "checkout",
      using: harness.git,
    )
    await harness.model.addProject(at: checkout)
    let project = try #require(harness.model.workspace.project(bare.standardizedFileURL.path))
    await harness.model.refreshBranchScan(of: project)
    harness.model.agentDetection = AgentDetection(found: ["claude": Self.claude])
    harness.model.setPreferredAgent("claude")
    let rows = harness.model.workspace.worktrees(of: project.id)
    let bareRow = try #require(rows.first { $0.isBare })

    #expect(!harness.model.canAutoRename(bareRow))
  }

  @Test func theTrunkBehindItsRemoteBaseWithNothingUnpushedCannotBeAutoRenamed() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let path = harness.project.path
    let remote = harness.root.appendingPathComponent("origin.git", isDirectory: true)
    _ = try await harness.git.run(
      ["clone", "-q", "--bare", path.path, remote.path],
      in: harness.root,
    )
    _ = try await harness.git.run(["remote", "add", "origin", remote.path], in: path)
    try await TestRepository.commit(
      "Ahead",
      files: ["ahead.txt": "a\n"],
      in: path,
      using: harness.git,
    )
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "main"], in: path)
    _ = try await harness.git.run(["reset", "-q", "--hard", "HEAD~1"], in: path)
    await harness.model.refreshBranchScan(of: harness.project)
    harness.model.agentDetection = AgentDetection(found: ["claude": Self.claude])
    harness.model.setPreferredAgent("claude")
    let main = try #require(harness.model.workspace.worktrees(of: harness.project.id).first)
    await harness.model.refreshStatuses()
    try await harness.statusReadsSettle(main)
    try #require(harness.model.statuses[main.id]?.behind == 1)

    #expect(!harness.model.canAutoRename(main))
  }

  @Test func theAgentStartsInTheWorktreeAndIsToldSo() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let requests = Requests()
    let feature = try await Self.committedFeature(
      in: harness,
      answering: Self.output("Billing export"),
      requests: requests,
    )
    harness.model.loginEnvironment = LoginShellEnvironment(
      variables: ["PWD": "/Users/someone", "OLDPWD": "/tmp", "PATH": "/usr/bin"],
      source: .processFallback(reason: "test"),
    )

    harness.model.autoRename(feature)
    try await Self.awaitEnd(of: feature, in: harness)

    let environment = try #require(requests.all.first).environment
    #expect(environment["PWD"] == feature.path.path)
    #expect(environment["OLDPWD"] == nil)
    #expect(environment["PATH"] == "/usr/bin")
  }

  @Test func quittingStopsARunningAgent() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let requests = Requests()
    let feature = try await Self.committedFeature(in: harness, answering: Self.output("x"))
    let gate = Scratch.path("auto-rename-quit-gate")
    defer { Scratch.remove(gate) }
    Self.holdRuns(in: harness, until: gate, requests: requests, answering: Self.output("x"))

    harness.model.autoRename(feature)
    try await waitUntil { !requests.all.isEmpty }
    harness.model.shutDown()

    #expect(try #require(requests.all.first).stopper.isStopRequested)
  }

  @Test func aFailureAtTheClickItselfPostsNoBanner() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await Self.committedFeature(in: harness, answering: Self.output("x"))
    harness.store.setNotificationPreference(NotificationPreference(notifiesOnFailure: true))
    harness.model.select(
      try #require(harness.model.workspace.worktrees(of: harness.project.id).first)
    )
    try #require(harness.model.worktreeIDInView != feature.id)
    harness.model.agentDetection = AgentDetection(found: [:])
    harness.model.loginEnvironment = LoginShellEnvironment(
      variables: [:],
      source: .processFallback(reason: "test"),
    )

    harness.model.autoRename(feature)

    #expect(harness.model.autoRenameFailure(of: feature.id) != nil)
    #expect(harness.notifier.posted.isEmpty, "the menu was just used; the row's warning says it")
  }

  @Test func anErrorOnStandardOutputIsShownPastAWarningOnStandardError() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await Self.committedFeature(
      in: harness,
      answering: Self.output(
        "Error: not signed in",
        status: 1,
        error: "(node:123) [DEP0040] DeprecationWarning: punycode",
      ),
    )

    harness.model.autoRename(feature)
    try await Self.awaitEnd(of: feature, in: harness)

    #expect(harness.model.autoRenameFailure(of: feature.id)?.contains("not signed in") == true)
  }

  @Test func aLandedBranchThatMovesAgainIsOfferedThoughItsMergeReadWaits() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.agentDetection = AgentDetection(found: ["claude": Self.claude])
    harness.model.setPreferredAgent("claude")
    var trees: [Worktree] = []
    for branch in ["one", "two"] {
      let tree = try await harness.createWorktree(onBranch: branch)
      _ = try await harness.git.run(
        ["commit", "-q", "--allow-empty", "-m", "work"],
        in: tree.path,
      )
      trees.append(tree)
    }
    for tree in trees {
      _ = try await harness.git.run(
        ["merge", "-q", "--no-ff", "-m", "merge", tree.name],
        in: harness.project.path,
      )
    }
    await harness.model.refreshBranchScans()
    try #require(trees.allSatisfy { harness.model.mergeState(of: $0) != .unmerged })
    harness.model.mergeReadLog.budget = .zero
    for tree in trees {
      _ = try await harness.git.run(
        ["commit", "-q", "--allow-empty", "-m", "more"],
        in: tree.path,
      )
    }

    await harness.model.refreshBranchScans()
    await harness.model.refreshStatuses()
    for tree in trees { try await harness.statusReadsSettle(tree) }

    #expect(trees.allSatisfy { harness.model.canAutoRename($0) })
  }

  @Test func aCheckoutTheListingHadNotSeenAtTheClickStillGetsItsName() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let requests = Requests()
    let feature = try await Self.committedFeature(
      in: harness,
      answering: Self.output("x"),
      requests: requests,
    )
    _ = try await harness.git.run(["checkout", "-q", "-b", "billing"], in: feature.path)
    try #require(harness.model.workspace.worktree(feature.id)?.branch == "feature")
    let gate = Scratch.path("auto-rename-lagging-gate")
    defer { Scratch.remove(gate) }
    Self.holdRuns(
      in: harness,
      until: gate,
      requests: requests,
      answering: Self.output("Billing export"),
    )

    harness.model.autoRename(feature)
    try await waitUntil { !requests.all.isEmpty }
    await harness.model.refreshWorktrees(of: harness.project)
    try #require(harness.model.workspace.worktree(feature.id)?.branch == "billing")
    FileManager.default.createFile(atPath: gate.path, contents: nil)
    try await Self.awaitEnd(of: feature, in: harness)

    #expect(harness.model.customName(of: feature) == "Billing export")
    #expect(requests.all.first?.arguments.last?.contains("Branch: billing") == true)
  }

  @Test func anAgentsStyledErrorIsShownWithoutItsEscapes() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await Self.committedFeature(
      in: harness,
      answering: Self.output("", status: 1, error: "\u{1b}[31mError:\u{1b}[0m not logged in"),
    )

    harness.model.autoRename(feature)
    try await Self.awaitEnd(of: feature, in: harness)

    let failure = try #require(harness.model.autoRenameFailure(of: feature.id))
    #expect(failure.contains("Error: not logged in"))
    #expect(!failure.contains("\u{1b}") && !failure.contains("[31m"))
  }

  @Test func anAgentWhoseLastLineIsOnlyAnEscapeStillSaysWhy() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let said = "Error: " + String(repeating: "x", count: 400) + "\n\u{1b}[?25h"
    let feature = try await Self.committedFeature(
      in: harness,
      answering: Self.output("\u{1b}[0m", status: 1, error: said),
    )

    harness.model.autoRename(feature)
    try await Self.awaitEnd(of: feature, in: harness)

    let failure = try #require(harness.model.autoRenameFailure(of: feature.id))
    #expect(failure.contains("xxxx"), "the reason, not an empty \"said: \"")
  }

  @Test func anAgentThatPrintsOnlyEscapesSaysItsExitStatus() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await Self.committedFeature(
      in: harness,
      answering: Self.output("\u{1b}[?25h", status: 3, error: "\u{1b}[0m"),
    )

    harness.model.autoRename(feature)
    try await Self.awaitEnd(of: feature, in: harness)

    #expect(harness.model.autoRenameFailure(of: feature.id)?.contains("exit status 3") == true)
  }

  @Test func aVerdictReadAgainstAnotherBaseDoesNotHoldTheItemBack() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.agentDetection = AgentDetection(found: ["claude": Self.claude])
    harness.model.setPreferredAgent("claude")
    _ = try await harness.git.run(["branch", "develop"], in: harness.project.path)
    var trees: [Worktree] = []
    for branch in ["one", "two"] {
      let tree = try await harness.createWorktree(onBranch: branch)
      _ = try await harness.git.run(
        ["commit", "-q", "--allow-empty", "-m", "work"],
        in: tree.path,
      )
      _ = try await harness.git.run(
        ["merge", "-q", "--no-ff", "-m", "merge", branch],
        in: harness.project.path,
      )
      trees.append(tree)
    }
    await harness.model.refreshBranchScans()
    try #require(trees.allSatisfy { harness.model.mergeState(of: $0) != .unmerged })
    harness.model.mergeReadLog.budget = .zero
    var settings = harness.model.ownSettings(of: harness.project)
    settings.defaultBranch = "develop"
    harness.model.setSettings(settings, for: harness.project)

    await harness.model.refreshBranchScans()
    await harness.model.refreshStatuses()
    for tree in trees { try await harness.statusReadsSettle(tree) }

    #expect(trees.allSatisfy { harness.model.canAutoRename($0) })
  }

  @Test func aDetachedHeadIsToldAsDetachedNotAsTheListingsBranch() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let requests = Requests()
    let feature = try await Self.committedFeature(
      in: harness,
      answering: Self.output("Billing export"),
      requests: requests,
    )
    _ = try await harness.git.run(["checkout", "-q", "--detach"], in: feature.path)
    try #require(harness.model.workspace.worktree(feature.id)?.branch == "feature")

    harness.model.autoRename(feature)
    try await Self.awaitEnd(of: feature, in: harness)

    let prompt = try #require(requests.all.first?.arguments.last)
    #expect(prompt.contains("Branch: none, HEAD is detached"))
    #expect(!prompt.contains("Branch: feature"))
  }

  @Test func anAgentWritingWindowsLineEndingsIsCutAtALine() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let said =
      (1...40).map { "line \($0) of the banner" }.joined(separator: "\r\n")
      + "\r\nError: not logged in"
    let feature = try await Self.committedFeature(
      in: harness,
      answering: Self.output("", status: 1, error: said),
    )

    harness.model.autoRename(feature)
    try await Self.awaitEnd(of: feature, in: harness)

    let failure = try #require(harness.model.autoRenameFailure(of: feature.id))
    #expect(failure.contains("Error: not logged in"))
    #expect(failure.contains("said: line "), "the cut lands on a whole line")
    #expect(!failure.contains("\r"))
  }
}
