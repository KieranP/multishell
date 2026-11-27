import Foundation
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit

@Suite(.serialized) @MainActor
struct AppModelBaseUpdateAbortTests {
  @Test func anAbortOverAWorkingAgentAsksFirstAndRunsOnlyOnceConfirmed() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureBehindOrigin(conflicting: true)
    await harness.model.requestBaseUpdate(of: feature, by: .rebase)
    _ = try harness.openAgentTab(in: feature, working: true)

    let detached = try #require(harness.model.workspace.worktree(feature.id))
    #expect(detached.branch == nil)
    await harness.model.abortBaseUpdate(of: detached, method: .rebase)
    let question = try #require(harness.model.pendingUpdateAbort)
    #expect(question.title == "Abort the rebase of feature?")
    #expect(question.message.hasPrefix("Claude Code is working in this worktree"))
    #expect(harness.model.statuses[feature.id]?.unfinishedUpdate == .rebase)

    await harness.model.answerUpdateAbort(question, confirmed: true)?.value

    #expect(harness.model.pendingUpdateAbort == nil)
    #expect(harness.model.statuses[feature.id]?.unfinishedUpdate == nil)
  }

  @Test func anAbortConfirmedAfterTheStopEndedOnlyRereadsTheRow() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureBehindOrigin(conflicting: true)
    await harness.model.requestBaseUpdate(of: feature, by: .rebase)
    _ = try harness.openAgentTab(in: feature, working: true)
    let detached = try #require(harness.model.workspace.worktree(feature.id))
    #expect(detached.branch == nil)
    await harness.model.abortBaseUpdate(of: detached, method: .rebase)
    let question = try #require(harness.model.pendingUpdateAbort)
    _ = try await harness.git.run(["rebase", "--abort"], in: feature.path)

    await harness.model.answerUpdateAbort(question, confirmed: true)?.value

    #expect(harness.model.presentedError == nil)
    #expect(harness.model.statuses[feature.id]?.unfinishedUpdate == nil)
  }

  @Test func anAbortConfirmedAfterAnotherStopTookItsPlaceLeavesThatStop() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureBehindOrigin(conflicting: true)
    await harness.model.requestBaseUpdate(of: feature, by: .rebase)
    _ = try harness.openAgentTab(in: feature, working: true)
    let detached = try #require(harness.model.workspace.worktree(feature.id))
    await harness.model.abortBaseUpdate(of: detached, method: .rebase)
    let question = try #require(harness.model.pendingUpdateAbort)
    _ = try await harness.git.run(["rebase", "--abort"], in: feature.path)
    _ = try? await harness.git.run(["merge", "--no-edit", "origin/main"], in: feature.path)

    await harness.model.answerUpdateAbort(question, confirmed: true)?.value

    #expect(harness.model.statuses[feature.id]?.unfinishedUpdate == .merge)
    #expect(harness.model.presentedError?.title == "Nothing was aborted in feature")
  }

  @Test func anAbortConfirmedAfterANewStopOfTheSameKindTookItsPlaceLeavesIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureBehindOrigin(conflicting: true)
    await harness.model.requestBaseUpdate(of: feature, by: .rebase)
    _ = try harness.openAgentTab(in: feature, working: true)
    let detached = try #require(harness.model.workspace.worktree(feature.id))
    await harness.model.abortBaseUpdate(of: detached, method: .rebase)
    let question = try #require(harness.model.pendingUpdateAbort)
    _ = try await harness.git.run(["rebase", "--abort"], in: feature.path)
    try "more\n".write(
      to: feature.path.appendingPathComponent("more.txt"),
      atomically: true,
      encoding: .utf8,
    )
    _ = try await harness.git.run(["add", "more.txt"], in: feature.path)
    _ = try await harness.git.run(["commit", "-q", "-m", "more"], in: feature.path)
    _ = try? await harness.git.run(["rebase", "origin/main"], in: feature.path)

    await harness.model.answerUpdateAbort(question, confirmed: true)?.value

    #expect(harness.model.statuses[feature.id]?.unfinishedUpdate == .rebase)
    #expect(harness.model.presentedError?.title == "Nothing was aborted in feature")
  }

  @Test func anAbortClickedFromAMenuNamingAnotherStopLeavesTheStopThere() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureBehindOrigin(conflicting: true)
    await harness.model.requestBaseUpdate(of: feature, by: .rebase)
    let detached = try #require(harness.model.workspace.worktree(feature.id))

    await harness.model.abortBaseUpdate(of: detached, method: .merge)

    #expect(harness.model.statuses[feature.id]?.unfinishedUpdate == .rebase)
  }

  @Test func aSecondAbortQuestionWhileOneStandsBeepsAndLeavesTheFirst() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureBehindOrigin(conflicting: true)
    await harness.model.requestBaseUpdate(of: feature, by: .rebase)
    _ = try harness.openAgentTab(in: feature, working: true)
    let detached = try #require(harness.model.workspace.worktree(feature.id))
    #expect(detached.branch == nil)
    await harness.model.abortBaseUpdate(of: detached, method: .rebase)
    let question = try #require(harness.model.pendingUpdateAbort)

    await harness.model.abortBaseUpdate(of: feature, method: .rebase)

    #expect(harness.platform.beeps == 1)
    #expect(harness.model.pendingUpdateAbort == question)
  }

  @Test func anUpdateQuestionWhileAnAbortQuestionStandsBeeps() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureBehindOrigin(conflicting: true)
    await harness.model.requestBaseUpdate(of: feature, by: .rebase)
    _ = try harness.openAgentTab(in: feature, working: true)
    await harness.model.abortBaseUpdate(
      of: try #require(harness.model.workspace.worktree(feature.id)),
      method: .rebase,
    )
    await harness.model.createWorktree(
      branch: "other",
      basedOn: "main~1",
      createsBranch: true,
      in: harness.project,
    )
    let other = try #require(harness.worktree(onBranch: "other"))
    _ = try harness.openAgentTab(in: other, working: true)

    await harness.model.requestBaseUpdate(of: other, by: .merge)

    #expect(harness.platform.beeps == 1)
    #expect(harness.model.pendingBaseUpdate == nil)
    #expect(harness.model.pendingUpdateAbort != nil)
  }
}
