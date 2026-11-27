import Foundation
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit

@Suite(.serialized) @MainActor
struct AppModelBaseUpdateMenuTests {
  @Test func theMenuNamesTheRemoteBaseAndOffersNothingOnTheBaseItself() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureBehindOrigin()
    let main = try #require(harness.worktree(onBranch: "main"))

    #expect(
      harness.model.baseUpdateMenu(for: feature) == .update(base: "origin/main", isRunning: false)
    )
    #expect(harness.model.baseUpdateMenu(for: main) == nil)
  }

  @Test func aConflictLeavesTheRebaseInProgressAndTheMenuOffersSendAndAbort() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureBehindOrigin(conflicting: true)
    let session = try harness.openAgentTab(in: feature, working: false)
    let before = try await harness.tip(of: feature)
    let opened = harness.engine.opened.count

    await harness.model.requestBaseUpdate(of: feature, by: .rebase)

    let status = try #require(harness.model.statuses[feature.id])
    #expect(status.unfinishedUpdate == .rebase)
    #expect(status.unfinishedUpdateText == "Rebasing · 1 conflict")
    let targets = ConflictSendTargets(
      recipients: harness.model.handoffRecipients(in: feature.id),
      opensAgentTab: false,
    )
    #expect(targets.recipients.map(\.id) == [session.id])
    #expect(
      harness.model.baseUpdateMenu(for: feature)
        == .unfinished(.rebase, sendTargets: targets, isRunning: false)
    )
    #expect(harness.engine.opened.count == opened, "nothing opened unasked with the setting off")

    await harness.model.requestUpdateAbort(of: feature, method: .rebase)

    #expect(try await harness.tip(of: feature) == before)
    #expect(harness.model.statuses[feature.id]?.unfinishedUpdate == nil)
    #expect(
      harness.model.baseUpdateMenu(for: feature) == .update(base: "origin/main", isRunning: false)
    )
  }
}
