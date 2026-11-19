import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellServices

@MainActor
@Suite
struct AppModelCIHandoffTests {
  /// As the CI page draws its foot, over the items it built for its rows.
  private static func footer(of worktree: Worktree, in harness: GitHarness) -> HandoffFooter? {
    guard case .run(let run) = harness.model.ciPage(of: worktree) else { return nil }
    return harness.model.ciHandoffFooter(
      of: worktree,
      over: harness.model.ciWorkflowListing(of: run, sendsFailures: true),
    )
  }

  @Test func theNewestRunsFailedJobIsCheckedAndSendIsOffered() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, agent, _) = try await harness.showingAFailedRun()

    let footer = Self.footer(of: feat, in: harness)

    guard case .ready(let picked, _, let canSend) = footer else {
      Issue.record("the foot offers Send, not \(String(describing: footer))")
      return
    }
    #expect(picked.id == agent.id)
    #expect(canSend)
  }

  @Test func sendWritesTheJobAndItsReportThenPastesAMentionAndMarksItSent() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, agent, _) = try await harness.showingAFailedRun()

    let outcome = harness.model.sendCIFailures(of: feat.id, to: agent.id, takingFocus: false)

    #expect(outcome.sentItemCount == 1)
    let file = try #require(HandoffDrops.files(in: harness.model.dropsDirectory).first)
    let text = try String(contentsOf: file, encoding: .utf8)
    #expect(file.lastPathComponent == "ci-feat.md")
    #expect(text.contains("## build / test-macos"))
    #expect(text.contains("    test-macos failed"))
    #expect(harness.engine.pasted.map(\.id) == [agent.id])
    let item = try #require(
      harness.model.ciHandoffItems(of: .sample(id: "r2", status: .failed)).first
    )
    #expect(
      harness.model.handoffState(of: item.candidate, in: feat.id) == .sent(agentName: "Claude Code")
    )
    #expect(Self.footer(of: feat, in: harness) == .sent(summary: "1 job sent to Claude Code"))
  }

  @Test func aReportReadBeforeItsRunsWorkflowsOffersNothingToSendYet() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    _ = try await harness.showingAFailedRun()
    let run = CIRun.sample(id: "r2", status: .failed)
    try #require(harness.model.failureReport(of: run) != nil)

    harness.model.remoteState.ciWorkflows[run.id] = nil

    #expect(harness.model.ciHandoffItems(of: run).isEmpty)
  }

  @Test func anUncheckedJobIsNotSentAndWithNothingCheckedSendIsOff() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, agent, _) = try await harness.showingAFailedRun()
    let item = try #require(
      harness.model.ciHandoffItems(of: .sample(id: "r2", status: .failed)).first
    )

    harness.model.toggleHandoffItem(item.candidate, in: feat.id)
    let outcome = harness.model.sendCIFailures(of: feat.id, to: agent.id, takingFocus: false)

    #expect(outcome == .nothingChecked)
    #expect(harness.engine.pasted.isEmpty)
    guard case .ready(_, _, let canSend) = Self.footer(of: feat, in: harness) else {
      Issue.record("the foot still offers the picker")
      return
    }
    #expect(!canSend)
  }

  @Test func checkingAJobAgainAfterSendTurnsTheFootBackToSend() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, agent, _) = try await harness.showingAFailedRun()
    let item = try #require(
      harness.model.ciHandoffItems(of: .sample(id: "r2", status: .failed)).first
    )
    harness.model.sendCIFailures(of: feat.id, to: agent.id, takingFocus: false)

    harness.model.unmarkHandoffItemSent(item.candidate.id, in: feat.id)

    guard case .ready(_, _, let canSend) = Self.footer(of: feat, in: harness) else {
      Issue.record("the foot offers Send again")
      return
    }
    #expect(canSend)
  }

  @Test func aNewerRunWithNothingToSendDropsWhatTheLastSendSaid() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, agent, provider) = try await harness.showingAFailedRun()
    harness.model.sendCIFailures(of: feat.id, to: agent.id, takingFocus: false)
    let tip = try await harness.tip(of: feat)
    let passed = CIRun.sample(id: "r3", branch: "feat", commit: tip, status: .passed)
    provider.answer(recent: [passed], workflows: [], history: [passed])

    await harness.model.refreshServices(ofProject: harness.project.id)
    harness.model.remoteState.panelReadLog.forget(PanelRead(worktree: feat.id, page: .ciRuns))
    await harness.model.readPanelServicesIfDue(of: feat)

    #expect(harness.model.ciPage(of: feat) == .run(passed))
    #expect(Self.footer(of: feat, in: harness) == nil)
  }

  @Test func aSentJobKeepsItsMarkThroughAPullRequestReadWhileItsRunDetailsAreUnloaded() async throws
  {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, agent, _) = try await harness.showingAFailedRun()
    let item = try #require(
      harness.model.ciHandoffItems(of: .sample(id: "r2", status: .failed)).first
    )
    harness.model.sendCIFailures(of: feat.id, to: agent.id, takingFocus: false)
    harness.model.remoteState.ciWorkflows["r2"] = nil
    harness.model.remoteState.failureReports["r2"] = nil

    harness.model.setFilesPanelMode(.pullRequest)
    await harness.model.readPanelServices(of: feat.id)

    #expect(
      harness.model.handoffState(of: item.candidate, in: feat.id) == .sent(agentName: "Claude Code")
    )
  }

  @Test func aSentRunOutputKeepsItsMarkWhileTheReportIsUnread() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (feat, agent, _) = try await harness.showingAFailedRun()
    let lintOnly = [
      CIWorkflow(
        name: "build",
        status: .failed,
        jobs: [CIJob(id: "11", name: "lint", status: .failed)],
      )
    ]
    harness.model.remoteState.ciWorkflows["r2"] = CIRunDetail(
      value: lintOnly,
      runStatus: .failed,
      runWasFinished: true,
    )
    let run = CIRun.sample(id: "r2", status: .failed)
    let output = try #require(harness.model.ciHandoffItems(of: run).first { $0.job == nil })
    harness.model.sendCIFailures(of: feat.id, to: agent.id, takingFocus: false)
    harness.model.remoteState.failureReports["r2"] = nil

    harness.model.pruneHandoffChoices(of: feat, after: .ciRuns)

    #expect(
      harness.model.handoffState(of: output.candidate, in: feat.id)
        == .sent(agentName: "Claude Code")
    )
  }
}
