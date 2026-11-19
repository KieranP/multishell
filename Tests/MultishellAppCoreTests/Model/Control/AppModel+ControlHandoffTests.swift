import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellServices

@MainActor
@Suite
struct AppModelControlHandoffTests {
  private static func sendPullRequestFeedback(
    to sessionID: UUID? = nil,
    includesChecks: Bool = true,
    includesThreads: Bool = true,
  ) -> ControlRequest {
    .sendPullRequestFeedback(
      worktree: nil,
      to: sessionID,
      includesChecks: includesChecks,
      includesThreads: includesThreads,
    )
  }

  @Test func prSendGivesThePickersAgentEveryCheckedItemAndSaysHowManyWentWhere() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, _, agent) = try await harness.showingAFailingPullRequest()

    let reply = await harness.model.answer(Self.sendPullRequestFeedback())

    let fields = reply.outputFields
    #expect(fields["worktree"] as? String == ControlID.worktree(feat.id))
    #expect(fields["pane"] as? String == agent.id.uuidString)
    #expect(fields["agent"] as? String == "Claude Code")
    #expect(fields["itemCount"] as? Int == 2)
    #expect(harness.engine.pasted.map(\.id) == [agent.id])
  }

  @Test func prSendLeavesTheKeyboardWhereItWas() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    _ = try await harness.showingAFailingPullRequest()
    let focusedBefore = harness.engine.focused

    _ = await harness.model.answer(Self.sendPullRequestFeedback())

    #expect(!harness.engine.pasted.isEmpty)
    #expect(harness.engine.focused == focusedBefore)
  }

  @Test func prSendWithChecksAloneSendsTheCheckAndLeavesTheThreadChecked() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, _, _) = try await harness.showingAFailingPullRequest()

    let reply = await harness.model.answer(Self.sendPullRequestFeedback(includesThreads: false))

    #expect(reply.outputFields["itemCount"] as? Int == 1)
    let pullRequest = try #require(harness.model.services(of: feat).shownPullRequest)
    let states = harness.model.pullRequestHandoffItems(of: pullRequest, in: feat).map { item in
      harness.model.handoffState(of: item.candidate, in: feat.id)
    }
    #expect(states == [.sent(agentName: "Claude Code"), .checked])
  }

  @Test func prSendWithNothingCheckedIsRefusedAsNothingToHandOff() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, _, _) = try await harness.showingAFailingPullRequest()
    let pullRequest = try #require(harness.model.services(of: feat).shownPullRequest)
    for item in harness.model.pullRequestHandoffItems(of: pullRequest, in: feat) {
      harness.model.toggleHandoffItem(item.candidate, in: feat.id)
    }

    let reply = await harness.model.answer(Self.sendPullRequestFeedback())

    #expect(reply == .refused(.nothingToHandOff(.pullRequest, id: ControlID.worktree(feat.id))))
    #expect(harness.engine.pasted.isEmpty)
  }

  @Test func prSendWithThreadsAloneWhereOnlyTheCheckIsCheckedIsRefused() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, _, _) = try await harness.showingAFailingPullRequest()
    let pullRequest = try #require(harness.model.services(of: feat).shownPullRequest)
    let thread = try #require(
      harness.model.pullRequestHandoffItems(of: pullRequest, in: feat).last
    )
    harness.model.toggleHandoffItem(thread.candidate, in: feat.id)

    let reply = await harness.model.answer(Self.sendPullRequestFeedback(includesChecks: false))

    #expect(reply == .refused(.nothingToHandOff(.pullRequest, id: ControlID.worktree(feat.id))))
  }

  @Test func prSendToAShellPaneIsRefusedAsHavingNoAgentToSendTo() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, _, _) = try await harness.showingAFailingPullRequest()
    harness.store.openTab(in: feat.id, title: "Shell")
    harness.model.reconcileSessions(takingFocus: false)
    let shell = try #require(
      harness.model.workspace.sessions(in: feat.id).first { $0.agentID == nil }
    )

    let reply = await harness.model.answer(Self.sendPullRequestFeedback(to: shell.id))

    #expect(reply == .refused(.noRecipient(id: ControlID.worktree(feat.id))))
    #expect(harness.model.handoffMiss(of: feat, on: .pullRequest) == nil)
  }

  @Test func prSendForAWorktreeWithNoPullRequestIsRefusedAsHavingNoPage() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    _ = try await harness.showingAFailingPullRequest()
    let main = try #require(harness.worktree(onBranch: "main"))
    let mainID = ControlID.worktree(main.id)

    let reply = await harness.model.answer(
      .sendPullRequestFeedback(
        worktree: mainID,
        to: nil,
        includesChecks: true,
        includesThreads: true,
      )
    )

    #expect(reply == .refused(.noServicePage(.pullRequest, id: mainID)))
  }

  @Test func prSendWhileAnotherSendReadsLogsIsRefusedAsReading() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, host, agent) = try await harness.showingAFailingPullRequest()
    host.holdLogs()
    let first = Task {
      await harness.model.sendPullRequestFeedback(of: feat.id, to: agent.id, takingFocus: false)
    }
    try await waitUntil { harness.readsLogs(of: feat) }

    let reply = await harness.model.answer(Self.sendPullRequestFeedback())
    host.releaseHeldReads()
    _ = await first.value

    #expect(reply == .refused(.handoffUnderWay(id: ControlID.worktree(feat.id))))
    #expect(harness.engine.pasted.map(\.id) == [agent.id])
  }

  @Test func prSendToAPaneClosedWhileItsLogsWereReadIsRefusedAsNoAgent() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, host, agent) = try await harness.showingAFailingPullRequest()
    host.holdLogs()
    let asking = Task { await harness.model.answer(Self.sendPullRequestFeedback()) }
    try await waitUntil { harness.readsLogs(of: feat) }
    let tab = try #require(harness.model.workspace.tab(owning: agent.id))

    harness.model.closeTab(tab.id)
    host.releaseHeldReads()
    let reply = await asking.value

    #expect(reply == .refused(.noRecipient(id: ControlID.worktree(feat.id))))
    #expect(harness.engine.pasted.isEmpty)
  }

  @Test func ciSendGivesThePickersAgentTheNewestRunsFailedJob() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, agent, _) = try await harness.showingAFailedRun()

    let reply = await harness.model.answer(.sendCIFailures(worktree: nil, to: nil))

    let fields = reply.outputFields
    #expect(fields["worktree"] as? String == ControlID.worktree(feat.id))
    #expect(fields["pane"] as? String == agent.id.uuidString)
    #expect(fields["agent"] as? String == "Claude Code")
    #expect(fields["itemCount"] as? Int == 1)
    #expect(harness.engine.pasted.map(\.id) == [agent.id])
  }

  @Test func ciSendWithTheFailedJobUncheckedIsRefusedAsNothingToHandOff() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, _, _) = try await harness.showingAFailedRun()
    let run = try #require(harness.model.services(of: feat).ciRun)
    for item in harness.model.ciHandoffItems(of: run) {
      harness.model.toggleHandoffItem(item.candidate, in: feat.id)
    }

    let reply = await harness.model.answer(.sendCIFailures(worktree: nil, to: nil))

    #expect(reply == .refused(.nothingToHandOff(.ciRuns, id: ControlID.worktree(feat.id))))
    #expect(harness.engine.pasted.isEmpty)
  }

  @Test func ciSendForAWorktreeWithNoRunIsRefusedAsHavingNoPage() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    _ = try await harness.showingAFailedRun()
    let main = try #require(harness.worktree(onBranch: "main"))
    let mainID = ControlID.worktree(main.id)

    let reply = await harness.model.answer(.sendCIFailures(worktree: mainID, to: nil))

    #expect(reply == .refused(.noServicePage(.ciRuns, id: mainID)))
  }

  @Test func prSendWhoseItemsWereAllUncheckedDuringTheReadIsRefusedAsNothingToHandOff() async throws
  {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, host, _) = try await harness.showingAFailingPullRequest()
    let pullRequest = try #require(harness.model.services(of: feat).shownPullRequest)
    let candidates = harness.model.pullRequestHandoffItems(of: pullRequest, in: feat).map(
      \.candidate
    )
    host.holdLogs()

    let asking = Task { await harness.model.answer(Self.sendPullRequestFeedback()) }
    try await waitUntil { harness.readsLogs(of: feat) }
    harness.model.toggleHandoffGroup(candidates, in: feat.id)
    host.releaseHeldReads()
    let reply = await asking.value

    #expect(reply == .refused(.nothingToHandOff(.pullRequest, id: ControlID.worktree(feat.id))))
    #expect(harness.engine.pasted.isEmpty)
  }

  @Test func prSendOfThreadsAloneGoesWhileAnotherSendReadsLogs() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, host, agent) = try await harness.showingAFailingPullRequest()
    host.holdLogs()
    let first = Task {
      await harness.model.sendPullRequestFeedback(of: feat.id, to: agent.id, takingFocus: false)
    }
    try await waitUntil { harness.readsLogs(of: feat) }

    let reply = await harness.model.answer(Self.sendPullRequestFeedback(includesChecks: false))
    host.releaseHeldReads()
    _ = await first.value

    #expect(reply.outputFields["itemCount"] as? Int == 1)
  }

  @Test func ciSendWithNothingCheckedAndNoAgentIsRefusedAsNothingToHandOff() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, agent, _) = try await harness.showingAFailedRun()
    let run = CIRun.sample(id: "r2", status: .failed)
    let candidates = harness.model.ciHandoffItems(of: run).map(\.candidate)
    harness.model.toggleHandoffGroup(candidates, in: feat.id)
    let tab = try #require(harness.model.workspace.tab(owning: agent.id))
    harness.model.closeTab(tab.id)

    let reply = await harness.model.answer(.sendCIFailures(worktree: nil, to: nil))

    #expect(reply == .refused(.nothingToHandOff(.ciRuns, id: ControlID.worktree(feat.id))))
  }
}
