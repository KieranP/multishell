import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellServices

@MainActor
@Suite
struct AppModelPullRequestHandoffTests {
  /// As the PR page draws its foot, along the path it drew.
  private static func footer(of worktree: Worktree, in harness: GitHarness) -> HandoffFooter? {
    guard let pullRequest = harness.model.services(of: worktree).shownPullRequest else {
      return nil
    }
    return harness.model.pullRequestHandoffFooter(
      of: worktree,
      along: harness.model.mergePath(of: pullRequest, in: worktree),
      on: pullRequest,
      threads: harness.model.unresolvedThreads(of: pullRequest, in: worktree),
    )
  }

  private static func handoffText(in drops: URL) throws -> (name: String, text: String) {
    let file = try #require(HandoffDrops.files(in: drops).first)
    return (file.lastPathComponent, try String(contentsOf: file, encoding: .utf8))
  }

  @Test func theOpenPullRequestsUnresolvedThreadsAreReadWithItsChecks() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, _, _) = try await harness.showingAFailingPullRequest()
    let pullRequest = try #require(harness.model.services(of: feat).shownPullRequest)

    #expect(harness.model.unresolvedThreads(of: pullRequest, in: feat).map(\.id) == ["t1"])
    #expect(harness.model.mergePath(of: pullRequest, in: feat).threadsStep == .comments)
  }

  @Test func sendReadsTheFailingChecksLogThenWritesItAndTheThreadAndMarksBothSent() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, host, agent) = try await harness.showingAFailingPullRequest()

    let outcome = await harness.model.sendPullRequestFeedback(
      of: feat.id,
      to: agent.id,
      takingFocus: false,
    )

    #expect(outcome.sentItemCount == 2)
    #expect(host.calls.contains("log test"))
    let file = try Self.handoffText(in: harness.model.dropsDirectory)
    #expect(file.name == "pr-9-feat.md")
    #expect(file.text.contains("## CI / test"))
    #expect(file.text.contains("    error: boom"))
    #expect(file.text.contains("## Sources/App.swift:12"))
    #expect(harness.engine.pasted.map(\.id) == [agent.id])
    #expect(
      Self.footer(of: feat, in: harness)
        == .sent(summary: "2 items sent to Claude Code")
    )
  }

  @Test func aPaneClosedWhileTheLogsWereReadGetsNothingAndTheFootSaysSo() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, host, agent) = try await harness.showingAFailingPullRequest()
    host.holdLogs()

    let sending = Task {
      await harness.model.sendPullRequestFeedback(of: feat.id, to: agent.id, takingFocus: false)
    }
    try await waitUntil { harness.readsLogs(of: feat) }
    #expect(Self.footer(of: feat, in: harness) == .reading("Reading 1 log"))
    let tab = try #require(harness.model.workspace.tab(owning: agent.id))
    harness.model.closeTab(tab.id)
    host.releaseHeldReads()
    let outcome = await sending.value

    #expect(outcome == .noRecipient)
    #expect(harness.engine.pasted.isEmpty)
    #expect(
      harness.model.handoffMiss(of: feat, on: .pullRequest)
        == "Claude Code was gone by the time the logs were read. Nothing was sent."
    )
  }

  @Test func aSendCancelledWhileItsLogsReadPastesNothingAndMarksNothingSent() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, host, agent) = try await harness.showingAFailingPullRequest()
    host.holdLogs()

    let sending = Task {
      await harness.model.sendPullRequestFeedback(of: feat.id, to: agent.id, takingFocus: false)
    }
    try await waitUntil { harness.readsLogs(of: feat) }
    sending.cancel()
    host.releaseHeldReads()
    let outcome = await sending.value

    #expect(outcome == .cancelled)
    #expect(harness.engine.pasted.isEmpty)
    let pullRequest = try #require(harness.model.services(of: feat).shownPullRequest)
    let check = try #require(
      harness.model.pullRequestHandoffItems(of: pullRequest, in: feat).first
    )
    #expect(harness.model.handoffState(of: check.candidate, in: feat.id) == .checked)
  }

  @Test func returningToAWorktreeBeforeTheIntervalReadsItsThreadsAgain() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, _, _) = try await harness.showingAFailingPullRequest()
    let main = try #require(harness.worktree(onBranch: "main"))
    let pullRequest = try #require(harness.model.services(of: feat).shownPullRequest)

    harness.model.select(main)
    await harness.model.readPanelServicesIfDue(of: main)
    harness.model.select(feat)
    await harness.model.readPanelServicesIfDue(of: feat)

    #expect(harness.model.unresolvedThreads(of: pullRequest, in: feat).map(\.id) == ["t1"])
  }

  @Test func anItemUncheckedWhileTheLogsReadIsNotSent() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, host, agent) = try await harness.showingAFailingPullRequest()
    let pullRequest = try #require(harness.model.services(of: feat).shownPullRequest)
    let thread = try #require(
      harness.model.pullRequestHandoffItems(of: pullRequest, in: feat).last?.candidate
    )
    host.holdLogs()

    let sending = Task {
      await harness.model.sendPullRequestFeedback(of: feat.id, to: agent.id, takingFocus: false)
    }
    try await waitUntil { harness.readsLogs(of: feat) }
    harness.model.toggleHandoffItem(thread, in: feat.id)
    host.releaseHeldReads()
    _ = await sending.value

    let file = try Self.handoffText(in: harness.model.dropsDirectory)
    #expect(!file.text.contains("Sources/App.swift:12"))
    #expect(harness.model.handoffState(of: thread, in: feat.id) == .unchecked)
  }

  @Test func aRemovedWorktreeKeepsNoThreadText() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, _, _) = try await harness.showingAFailingPullRequest()

    harness.model.forgetWorktrees([feat.id])

    #expect(harness.model.remoteState.threads[feat.id] == nil)
  }

  @Test func aThreadReadLandingAfterThePanelMovedOnKeepsNoText() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, host, _) = try await harness.showingAFailingPullRequest()
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.remoteState.panelReadLog.forget(PanelRead(worktree: feat.id, page: .pullRequest))
    let threadReadsBefore = host.calls.count { $0 == "threads #9" }
    host.holdThreads()

    let reading = Task { await harness.model.readPanelServices(of: feat.id) }
    try await waitUntil { host.calls.count { $0 == "threads #9" } > threadReadsBefore }
    harness.model.select(main)
    harness.model.remoteState.threads[feat.id] = nil
    host.releaseHeldReads()
    _ = await reading.value

    #expect(harness.model.remoteState.threads[feat.id] == nil)
  }

  @Test func aMergedPullRequestCarriesNoneOfItsCachedThreadsToSend() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, host, _) = try await harness.showingAFailingPullRequest()
    let tip = try await harness.tip(of: feat)
    host.answer(
      .success([.sample(number: 9, state: .merged, headBranch: "feat", headCommit: tip)])
    )

    await harness.model.refreshServices(ofProject: harness.project.id)

    let pullRequest = try #require(harness.model.services(of: feat).shownPullRequest)
    try #require(pullRequest.state == .merged)
    let threads = harness.model.pullRequestHandoffItems(of: pullRequest, in: feat).filter { item in
      if case .thread = item { true } else { false }
    }
    #expect(threads.isEmpty)
  }

  @Test func aThreadReReadWhileTheLogsReadIsStillSent() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, host, agent) = try await harness.showingAFailingPullRequest()
    host.holdLogs()

    let sending = Task {
      await harness.model.sendPullRequestFeedback(of: feat.id, to: agent.id, takingFocus: false)
    }
    try await waitUntil { harness.readsLogs(of: feat) }
    host.answerThreads(.success([.sample(isOutdated: true)]))
    await harness.model.readPanelServices(of: feat.id)
    host.releaseHeldReads()
    let outcome = await sending.value

    #expect(outcome.sentItemCount == 2)
  }

  @Test func selectingAWorktreeOnAnotherPageDropsTheLastOnesThreadText() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, _, _) = try await harness.showingAFailingPullRequest()
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.setFilesPanelMode(.files)

    harness.model.select(main)
    harness.model.schedulePanelServicesRead(of: main.id)
    try await waitUntil { harness.model.remoteState.threads[feat.id] == nil }

    #expect(harness.model.remoteState.threads[feat.id] == nil)
  }

  @Test func aSendThePaneTookNoPasteOfSaysSoOverTheFoot() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, _, agent) = try await harness.showingAFailingPullRequest()
    harness.engine.liveSessionIDs.remove(agent.id)

    let outcome = await harness.model.sendPullRequestFeedback(
      of: feat.id,
      to: agent.id,
      takingFocus: false,
    )

    #expect(outcome == .notPasted(to: agent.id))
    #expect(
      harness.model.handoffMiss(of: feat, on: .pullRequest)
        == "Nothing was sent to Claude Code: its pane took no paste."
    )
  }

  @Test func aSendForAWorktreeOffThePanelReadsItsThreadsRatherThanDroppingThem() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, _, agent) = try await harness.showingAFailingPullRequest()
    harness.model.select(try #require(harness.worktree(onBranch: "main")))
    harness.model.remoteState.threads[feat.id] = nil

    let outcome = await harness.model.sendPullRequestFeedback(
      of: feat.id,
      to: agent.id,
      takingFocus: false,
    )

    #expect(outcome.sentItemCount == 2)
    let file = try Self.handoffText(in: harness.model.dropsDirectory)
    #expect(file.text.contains("## Sources/App.swift:12"))
  }

  @Test func aPageWhoseThreadsCouldNotBeReadStillSendsItsCheckedCheck() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, host, agent) = try await harness.showingAFailingPullRequest()
    host.answerThreads(.failure(.failed("SSO required")))
    harness.model.remoteState.threads[feat.id] = PullRequestThreads(
      pullRequestNumber: 9,
      threads: nil,
      failure: .failed("SSO required"),
    )

    let outcome = await harness.model.sendPullRequestFeedback(
      of: feat.id,
      to: agent.id,
      takingFocus: false,
    )

    #expect(outcome.sentItemCount == 1)
  }

  @Test func checksReadWhileThreadsFailStillLetGoOfAnOldHeadsPicks() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, _, _) = try await harness.showingAFailingPullRequest()
    let oldHead = HandoffCandidate(.check(name: "CI / test", link: nil, headCommit: "old"))
    harness.model.toggleHandoffItem(oldHead, in: feat.id)
    harness.model.remoteState.threads[feat.id] = PullRequestThreads(
      pullRequestNumber: 9,
      threads: nil,
      failure: .failed("SSO required"),
    )

    harness.model.pruneHandoffChoices(of: feat, after: .pullRequest)

    #expect(harness.model.handoffState(of: oldHead, in: feat.id) == .checked)
  }

  @Test func aSecondSendWhileTheFirstReadsItsThreadsIsRefusedAsReading() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, host, agent) = try await harness.showingAFailingPullRequest()
    harness.model.select(try #require(harness.worktree(onBranch: "main")))
    harness.model.remoteState.threads[feat.id] = nil
    let threadReadsBefore = host.calls.count { $0 == "threads #9" }
    host.holdThreads()

    let first = Task {
      await harness.model.sendPullRequestFeedback(of: feat.id, to: agent.id, takingFocus: false)
    }
    try await waitUntil { host.calls.count { $0 == "threads #9" } > threadReadsBefore }
    let secondOutcome = MainActorBox<HandoffSendOutcome>()
    Task {
      secondOutcome.value = await harness.model.sendPullRequestFeedback(
        of: feat.id,
        to: agent.id,
        takingFocus: false,
      )
    }
    try await waitUntil { secondOutcome.value != nil }
    let beforeTheReadEnded = secondOutcome.value
    host.releaseHeldReads()
    _ = await first.value

    #expect(beforeTheReadEnded == .alreadySending)
  }

  @Test func threadsAloneOnAPageWhoseThreadReadFailedSayWhy() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, _, agent) = try await harness.showingAFailingPullRequest()
    harness.model.remoteState.threads[feat.id] = PullRequestThreads(
      pullRequestNumber: 9,
      threads: nil,
      failure: .failed("SSO required"),
    )

    let outcome = await harness.model.sendPullRequestFeedback(
      of: feat.id,
      to: agent.id,
      takingFocus: false,
      includesChecks: false,
    )

    guard case .threadsNotRead = outcome else {
      Issue.record("refused as the threads not read, not \(outcome)")
      return
    }
  }

  @Test func aSendToAPaneClosedSinceThePickerDrewSaysSoOverTheFoot() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, _, agent) = try await harness.showingAFailingPullRequest()
    let tab = try #require(harness.model.workspace.tab(owning: agent.id))
    harness.model.closeTab(tab.id)

    _ = await harness.model.sendPullRequestFeedback(of: feat.id, to: agent.id, takingFocus: false)

    #expect(
      harness.model.handoffMiss(of: feat, on: .pullRequest)
        == "The pane picked has closed. Pick another."
    )
  }

  @Test func aFileThatCannotBeWrittenIsSaidByItsAlertAloneNotTwice() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, _, agent) = try await harness.showingAFailingPullRequest()
    let drops = harness.model.dropsDirectory
    try? FileManager.default.removeItem(at: drops)
    try Data("not a directory".utf8).write(to: drops)

    _ = await harness.model.sendPullRequestFeedback(of: feat.id, to: agent.id, takingFocus: false)

    #expect(harness.model.presentedError != nil)
    #expect(harness.model.handoffMiss(of: feat, on: .pullRequest) == nil)
  }

  @Test func theFootCountsOnlyTheLogsTheHostCanRead() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, host, agent) = try await harness.showingAFailingPullRequest()
    host.answerChecks([
      .sample(name: "test", status: .failed, link: GitHarness.failingCheckLink),
      .sample(
        name: "circle",
        workflow: nil,
        status: .failed,
        link: URL(string: "https://circleci.com/x"),
      ),
    ])
    harness.model.remoteState.panelReadLog.forget(PanelRead(worktree: feat.id, page: .pullRequest))
    await harness.model.readPanelServices(of: feat.id)
    host.holdLogs()

    let sending = Task {
      await harness.model.sendPullRequestFeedback(of: feat.id, to: agent.id, takingFocus: false)
    }
    try await waitUntil { harness.readsLogs(of: feat) }
    let phase = harness.model.handoff.sendPhases[feat.id]
    host.releaseHeldReads()
    _ = await sending.value

    #expect(phase == .readingLogs(count: 1))
  }

  @Test func theFootSaysASendIsUnderWayBeforeItsLogsAreRead() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, host, agent) = try await harness.showingAFailingPullRequest()
    harness.model.select(try #require(harness.worktree(onBranch: "main")))
    harness.model.remoteState.threads[feat.id] = nil
    let threadReadsBefore = host.calls.count { $0 == "threads #9" }
    host.holdThreads()

    let sending = Task {
      await harness.model.sendPullRequestFeedback(of: feat.id, to: agent.id, takingFocus: false)
    }
    try await waitUntil { host.calls.count { $0 == "threads #9" } > threadReadsBefore }
    let footer = Self.footer(of: feat, in: harness)
    host.releaseHeldReads()
    _ = await sending.value

    guard case .reading = footer else {
      Issue.record("the foot says the Send is under way, not \(String(describing: footer))")
      return
    }
  }

  @Test func aPageSendBeforeItsFirstThreadReadSendsNoThreadItHasNotShown() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, _, agent) = try await harness.showingAFailingPullRequest()
    harness.model.remoteState.threads[feat.id] = nil

    harness.model.select(feat)
    let outcome = await harness.model.sendPullRequestFeedback(
      of: feat.id,
      to: agent.id,
      takingFocus: false,
    )

    #expect(outcome.sentItemCount == 1)
  }

  @Test func aSendForThePanelsWorktreeOnAnotherPageReadsItsThreadsRatherThanDroppingThem()
    async throws
  {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, _, agent) = try await harness.showingAFailingPullRequest()
    harness.model.setFilesPanelMode(.files)
    harness.model.select(feat)
    harness.model.remoteState.threads[feat.id] = nil

    let outcome = await harness.model.sendPullRequestFeedback(
      of: feat.id,
      to: agent.id,
      takingFocus: false,
    )

    #expect(outcome.sentItemCount == 2)
  }

  @Test func aSendForThePanelsWorktreeOnAnotherPageReadsItsThreadsAfreshNotAsLastShown()
    async throws
  {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, host, agent) = try await harness.showingAFailingPullRequest()
    harness.model.setFilesPanelMode(.files)
    harness.model.select(feat)
    host.answerThreads(.success([.sample(id: "t9", path: "Sources/New.swift")]))

    _ = await harness.model.sendPullRequestFeedback(of: feat.id, to: agent.id, takingFocus: false)

    let file = try Self.handoffText(in: harness.model.dropsDirectory)
    #expect(file.text.contains("## Sources/New.swift:12"))
    #expect(!file.text.contains("## Sources/App.swift:12"))
  }

  @Test func aSendOffThePullRequestPageReadsItsChecksAfreshNotAsLastShown() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, host, agent) = try await harness.showingAFailingPullRequest()
    harness.model.setFilesPanelMode(.files)
    harness.model.select(feat)
    host.answerChecks([.sample(name: "test", status: .passed, link: GitHarness.failingCheckLink)])

    let outcome = await harness.model.sendPullRequestFeedback(
      of: feat.id,
      to: agent.id,
      takingFocus: false,
    )

    #expect(outcome.sentItemCount == 1)
  }

  @Test func aSendWhileTheAppIsInTheBackgroundReadsAfreshAsThePagePausedItsReads()
    async throws
  {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, host, agent) = try await harness.showingAFailingPullRequest()
    harness.platform.isActive = false
    host.answerThreads(.success([.sample(id: "t9", path: "Sources/New.swift")]))

    _ = await harness.model.sendPullRequestFeedback(
      of: feat.id,
      to: agent.id,
      takingFocus: false,
      includesChecks: false,
    )

    let file = try Self.handoffText(in: harness.model.dropsDirectory)
    #expect(file.text.contains("## Sources/New.swift:12"))
  }

  @Test func checksReadOffThePageAfterAPushAreCaptionedWithTheHeadTheyRanOn() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, host, agent) = try await harness.showingAFailingPullRequest()
    harness.model.setFilesPanelMode(.files)
    harness.model.select(feat)
    host.answerHeadCommit("0123456789abcdef0123456789abcdef01234567")

    _ = await harness.model.sendPullRequestFeedback(
      of: feat.id,
      to: agent.id,
      takingFocus: false,
      includesThreads: false,
    )

    let file = try Self.handoffText(in: harness.model.dropsDirectory)
    #expect(file.text.contains("This ran on 0123456"))
  }

  @Test func checksAloneOnAPageWhoseChecksReadFailedSayWhy() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, _, agent) = try await harness.showingAFailingPullRequest()
    let pullRequest = try #require(harness.model.services(of: feat).shownPullRequest)
    harness.model.remoteState.checks[feat.id] = PullRequestChecks(
      pullRequestNumber: pullRequest.number,
      headCommit: pullRequest.headCommit,
      checks: nil,
      failure: .failed("SSO required"),
    )

    let outcome = await harness.model.sendPullRequestFeedback(
      of: feat.id,
      to: agent.id,
      takingFocus: false,
      includesThreads: false,
    )

    #expect(outcome == .checksNotRead(reason: "SSO required"))
  }

  @Test func checksAloneOffThePullRequestPageWhoseReadFailsSayWhy() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, host, agent) = try await harness.showingAFailingPullRequest()
    harness.model.setFilesPanelMode(.files)
    harness.model.select(feat)
    host.failChecks(.failed("SSO required"))

    let outcome = await harness.model.sendPullRequestFeedback(
      of: feat.id,
      to: agent.id,
      takingFocus: false,
      includesThreads: false,
    )

    #expect(outcome == .checksNotRead(reason: "SSO required"))
    #expect(harness.engine.pasted.isEmpty)
  }

  @Test func aSendThatFindsNothingCheckedClearsTheLastMissNote() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, _, agent) = try await harness.showingAFailingPullRequest()
    harness.model.noteHandoffMiss("an old note", on: .pullRequest, in: feat.id)
    let pullRequest = try #require(harness.model.services(of: feat).shownPullRequest)
    let candidates = harness.model.pullRequestHandoffItems(of: pullRequest, in: feat).map(
      \.candidate
    )
    harness.model.toggleHandoffGroup(candidates, in: feat.id)

    _ = await harness.model.sendPullRequestFeedback(of: feat.id, to: agent.id, takingFocus: false)

    #expect(harness.model.handoffMiss(of: feat, on: .pullRequest) == nil)
  }
}
