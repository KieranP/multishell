import Foundation
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit

@Suite(.serialized) @MainActor
struct AppModelBaseUpdatesTests {
  @Test func aCleanWorktreeWithNoAgentIsMergedWithoutAQuestion() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureBehindOrigin()

    await harness.model.requestBaseUpdate(of: feature, by: .merge)

    #expect(harness.model.pendingBaseUpdate == nil)
    #expect(harness.model.presentedError == nil)
    #expect(await harness.contains("origin/main", in: feature))
    #expect(harness.model.baseUpdateSteps.isEmpty)
  }

  @Test func uncommittedChangesRefuseTheUpdateNamingEachFileAndStashNothing() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureBehindOrigin()
    try "edited\n".write(
      to: feature.path.appendingPathComponent("feature.txt"),
      atomically: true,
      encoding: .utf8,
    )
    try "new\n".write(
      to: feature.path.appendingPathComponent("notes.md"),
      atomically: true,
      encoding: .utf8,
    )

    await harness.model.requestBaseUpdate(of: feature, by: .rebase)

    let alert = try #require(harness.model.presentedError)
    #expect(alert.title == "feature has uncommitted changes")
    #expect(alert.message.hasSuffix("\n\nM feature.txt\n? notes.md"))
    #expect(alert.message.contains("rebasing onto origin/main"))
    #expect(!(await harness.contains("origin/main", in: feature)))
    #expect(try await harness.git.run(["stash", "list"], in: feature.path).isEmpty)
  }

  @Test func aRebaseOfAPushedBranchAsksAndRunsOnlyOnceConfirmed() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureBehindOrigin()
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "feature"], in: feature.path)

    await harness.model.requestBaseUpdate(of: feature, by: .rebase)
    let question = try #require(harness.model.pendingBaseUpdate)
    #expect(question.title == "Rebase feature onto origin/main?")
    #expect(question.message.contains("--force-with-lease"))
    #expect(!(await harness.contains("origin/main", in: feature)))

    await harness.model.answerBaseUpdate(question, confirmed: true)?.value

    #expect(harness.model.pendingBaseUpdate == nil)
    #expect(await harness.contains("origin/main", in: feature))
  }

  @Test func aMergeOfAPushedBranchDoesNotAsk() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureBehindOrigin()
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "feature"], in: feature.path)

    await harness.model.requestBaseUpdate(of: feature, by: .merge)

    #expect(harness.model.pendingBaseUpdate == nil)
    #expect(await harness.contains("origin/main", in: feature))
  }

  @Test func aWorkingAgentAsksFirstAndACancelLeavesTheBranch() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureBehindOrigin()
    _ = try harness.openAgentTab(in: feature, working: true)

    await harness.model.requestBaseUpdate(of: feature, by: .merge)
    let question = try #require(harness.model.pendingBaseUpdate)
    #expect(question.message.contains("Claude Code is working in this worktree"))
    #expect(!question.message.contains("--force-with-lease"))

    #expect(harness.model.answerBaseUpdate(question, confirmed: false) == nil)

    #expect(harness.model.pendingBaseUpdate == nil)
    #expect(!(await harness.contains("origin/main", in: feature)))
  }

  @Test func aSecondQuestionWhileOneStandsBeepsAndACleanUpdateStillRuns() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureBehindOrigin()
    await harness.model.createWorktree(
      branch: "clean",
      basedOn: "main~1",
      createsBranch: true,
      in: harness.project,
    )
    let clean = try #require(harness.worktree(onBranch: "clean"))
    #expect(!(await harness.contains("origin/main", in: clean)))
    _ = try harness.openAgentTab(in: feature, working: true)
    await harness.model.requestBaseUpdate(of: feature, by: .merge)
    let question = try #require(harness.model.pendingBaseUpdate)

    await harness.model.requestBaseUpdate(of: feature, by: .rebase)
    await harness.model.requestBaseUpdate(of: clean, by: .merge)

    #expect(harness.platform.beeps == 1)
    #expect(harness.model.pendingBaseUpdate == question)
    #expect(await harness.contains("origin/main", in: clean))
  }

  @Test func anUpdatesQuestionWaitsBehindAnotherKindOfQuestionWithABeep() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureBehindOrigin()
    _ = try harness.openAgentTab(in: feature, working: true)
    harness.model.pendingBranchPublish = PendingBranchPublish(
      worktree: feature,
      branch: "feature",
      remote: "origin",
      remoteBranch: "feature",
      unpushedCommits: 1,
    )

    await harness.model.requestBaseUpdate(of: feature, by: .merge)

    #expect(harness.platform.beeps == 1)
    #expect(harness.model.pendingBaseUpdate == nil)
  }

  @Test func changesMadeWhileTheQuestionStoodRefuseTheConfirmedUpdate() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureBehindOrigin()
    _ = try harness.openAgentTab(in: feature, working: true)
    await harness.model.requestBaseUpdate(of: feature, by: .merge)
    let question = try #require(harness.model.pendingBaseUpdate)
    try "agent edit\n".write(
      to: feature.path.appendingPathComponent("feature.txt"),
      atomically: true,
      encoding: .utf8,
    )

    await harness.model.answerBaseUpdate(question, confirmed: true)?.value

    #expect(harness.model.presentedError?.title == "feature has uncommitted changes")
    #expect(!(await harness.contains("origin/main", in: feature)))
  }

  @Test func anUpdateConfirmedOnceItsWorktreesRemovalHasBegunRunsNothing() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureBehindOrigin()
    _ = try harness.openAgentTab(in: feature, working: true)
    await harness.model.requestBaseUpdate(of: feature, by: .merge)
    let question = try #require(harness.model.pendingBaseUpdate)
    let gate = harness.root.appendingPathComponent("gate")
    harness.model.setSettings(
      ProjectSettings(preDeleteHook: harness.holdLine(until: gate)),
      for: harness.project,
    )
    let removal = Task {
      await harness.model.removeWorktree(feature, deletesBranch: false, trashes: false)
    }
    try await waitUntil(
      { harness.model.worktreeOperations[feature.id]?.stage == .preDeleteHook },
      seconds: 10,
    )

    await harness.model.answerBaseUpdate(question, confirmed: true)?.value
    let merged = await harness.contains("origin/main", in: feature)
    FileManager.default.createFile(atPath: gate.path, contents: nil)
    _ = await removal.value

    #expect(!merged)
  }

  @Test func anUpdateConfirmedAfterTheAgentSwitchedBranchRunsNothingAndSaysWhy() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureBehindOrigin()
    _ = try harness.openAgentTab(in: feature, working: true)
    await harness.model.requestBaseUpdate(of: feature, by: .rebase)
    let question = try #require(harness.model.pendingBaseUpdate)
    _ = try await harness.git.run(["switch", "-q", "-c", "hotfix"], in: feature.path)

    await harness.model.answerBaseUpdate(question, confirmed: true)?.value

    #expect(!(await harness.contains("origin/main", in: feature)))
    #expect(harness.model.presentedError?.title == "feature is no longer checked out")
  }

  @Test func anUpdateConfirmedAfterTheProjectsBaseWentRunsNothingAndSaysSo() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureBehindOrigin()
    _ = try harness.openAgentTab(in: feature, working: true)
    await harness.model.requestBaseUpdate(of: feature, by: .merge)
    let question = try #require(harness.model.pendingBaseUpdate)
    harness.model.setSettings(
      ProjectSettings(defaultBranch: "no-such-trunk"),
      for: harness.project,
    )
    await harness.model.refreshBranchScan(of: harness.project)

    await harness.model.answerBaseUpdate(question, confirmed: true)?.value

    #expect(!(await harness.contains("origin/main", in: feature)))
    #expect(harness.model.presentedError?.title == "feature's base changed")
  }

  @Test func theBasesOwnCheckoutOffersNoUpdateWhenItsRemoteNameHoldsASlash() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    try await harness.addOrigin()
    let origin = try await harness.git.run(
      ["remote", "get-url", "origin"],
      in: harness.project.path,
    )
    .trimmingCharacters(in: .whitespacesAndNewlines)
    _ = try await harness.git.run(
      ["remote", "add", "team/origin", origin],
      in: harness.project.path,
    )
    _ = try await harness.git.run(["fetch", "-q", "team/origin"], in: harness.project.path)
    harness.model.setSettings(
      ProjectSettings(defaultBranch: "team/origin/main"),
      for: harness.project,
    )
    await harness.model.refreshBranchScan(of: harness.project)
    let main = try #require(harness.worktree(onBranch: "main"))

    #expect(harness.model.defaultBranch(of: harness.project)?.shortName == "team/origin/main")
    #expect(harness.model.updatableBase(of: main) == nil)
  }

  @Test func aStopTheRowHadNotReadIsNamedRatherThanCalledUncommittedChanges() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureBehindOrigin(conflicting: true)
    _ = try? await harness.git.run(["merge", "--no-edit", "origin/main"], in: feature.path)
    harness.clearStatuses()

    await harness.model.requestBaseUpdate(of: feature, by: .rebase)

    #expect(harness.model.presentedError?.title == "feature has the merge stopped partway")
    #expect(harness.model.statuses[feature.id]?.unfinishedUpdate == .merge)
  }

  @Test func aStoppedCherryPickIsNamedRatherThanCalledUncommittedChanges() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureBehindOrigin(conflicting: true)
    _ = try? await harness.git.run(["cherry-pick", "origin/main"], in: feature.path)

    await harness.model.requestBaseUpdate(of: feature, by: .merge)

    #expect(
      harness.model.presentedError?.title
        == "feature has a cherry-pick, revert or git am stopped partway"
    )
  }

  @Test func changesMadeDuringTheFetchRefuseTheMerge() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureBehindOrigin()
    let edited = feature.path.appendingPathComponent("agent-notes.md")
    try harness.wrapGit(
      in: """
        [ "$1" = fetch ] && echo "agent edit" > '\(edited.path)'
        """
    )

    await harness.model.requestBaseUpdate(of: feature, by: .merge)

    #expect(harness.model.presentedError?.title == "feature has uncommitted changes")
    #expect(!(await harness.contains("origin/main", in: feature)))
  }

  @Test func anUpdateFindingTheIndexLockedSaysSoAndStartsNothing() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureBehindOrigin()
    let record = try #require(WorktreeGit.recordDirectoryFromGitFile(in: feature.path))
    try Data().write(to: record.appendingPathComponent("index.lock"))

    await harness.model.requestBaseUpdate(of: feature, by: .rebase)

    let alert = try #require(harness.model.presentedError)
    #expect(alert.title == "The index is locked")
    #expect(alert.message.contains("index.lock"))
    #expect(harness.model.statuses[feature.id]?.unfinishedUpdate == nil)
    #expect(harness.model.baseUpdateSteps.isEmpty)
  }

  @Test func theRowSaysFetchingWhileTheBaseIsFetched() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureBehindOrigin()
    let gate = harness.root.appendingPathComponent("gate")
    let fetching = harness.root.appendingPathComponent("fetching")
    try harness.holdFetches(until: gate, touching: fetching)

    let update = Task { await harness.model.requestBaseUpdate(of: feature, by: .merge) }
    try await harness.awaitFetch(fetching)
    let step = harness.model.baseUpdateSteps[feature.id]
    try Data().write(to: gate)
    await update.value

    #expect(step == .fetching)
  }

  @Test func aWorktreeCannotBeRemovedWhileItsUpdateRuns() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureBehindOrigin()
    let gate = harness.root.appendingPathComponent("gate")
    let fetching = harness.root.appendingPathComponent("fetching")
    try harness.holdFetches(until: gate, touching: fetching)

    let update = Task { await harness.model.requestBaseUpdate(of: feature, by: .merge) }
    try await harness.awaitFetch(fetching)
    let canRemove = harness.model.canRemove(feature)
    try Data().write(to: gate)
    await update.value

    #expect(!canRemove)
  }

  @Test func aRemovalConfirmedWhileAnUpdateRunsThereRemovesNothing() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureBehindOrigin()
    let gate = harness.root.appendingPathComponent("gate")
    let fetching = harness.root.appendingPathComponent("fetching")
    try harness.holdFetches(until: gate, touching: fetching)
    let update = Task { await harness.model.requestBaseUpdate(of: feature, by: .merge) }
    try await harness.awaitFetch(fetching)

    await harness.model.removeWorktree(feature, deletesBranch: false, trashes: false)
    try Data().write(to: gate)
    await update.value

    #expect(FileManager.default.fileExists(atPath: feature.path.path))
  }

  @Test func aBranchSwitchedDuringTheFetchIsNotUpdated() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureBehindOrigin()
    let gate = harness.root.appendingPathComponent("gate")
    let fetching = harness.root.appendingPathComponent("fetching")
    try harness.holdFetches(
      until: gate,
      touching: fetching,
      during: "git switch -q -c hotfix",
    )
    try Data().write(to: gate)

    await harness.model.requestBaseUpdate(of: feature, by: .merge)

    #expect(!(await harness.contains("origin/main", in: feature)))
    #expect(harness.model.presentedError?.title == "feature is no longer checked out")
  }

  @Test func anUpdateWhoseTaskIsCancelledDuringTheFetchRunsNoMerge() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureBehindOrigin()
    let gate = harness.root.appendingPathComponent("gate")
    let fetching = harness.root.appendingPathComponent("fetching")
    try harness.holdFetches(until: gate, touching: fetching)

    let update = Task { await harness.model.requestBaseUpdate(of: feature, by: .merge) }
    try await harness.awaitFetch(fetching)
    update.cancel()
    try Data().write(to: gate)
    await update.value

    #expect(!(await harness.contains("origin/main", in: feature)))
  }

  @Test func aConfirmAsksAgainWhereAReasonAroseWhileTheQuestionStood() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureBehindOrigin()
    _ = try await harness.git.run(["push", "-q", "origin", "feature:feature"], in: feature.path)
    await harness.model.requestBaseUpdate(of: feature, by: .rebase)
    let question = try #require(harness.model.pendingBaseUpdate)
    #expect(!question.message.contains("is working"))
    _ = try harness.openAgentTab(in: feature, working: true)

    await harness.model.answerBaseUpdate(question, confirmed: true)?.value

    #expect(!(await harness.contains("origin/main", in: feature)))
    #expect(harness.model.pendingBaseUpdate?.message.contains("Claude Code is working") == true)
  }
}
