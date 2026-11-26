import Foundation
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit

@Suite(.serialized) @MainActor
struct AppModelControlBaseUpdatesTests {
  private static func update(
    _ worktree: Worktree,
    by method: UpdateMethod,
    force: Bool = false,
    allowsRewritingPushedBranch: Bool = false,
  ) -> ControlRequest {
    .updateWorktree(
      WorktreeUpdateOrder(
        worktreeID: ControlID.worktree(worktree.id),
        method: method,
        force: force,
        allowsRewritingPushedBranch: allowsRewritingPushedBranch,
      )
    )
  }

  @Test func anUpdateRequestMergesAndSaysItUpdated() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureBehindOrigin()

    let reply = await harness.model.answer(Self.update(feature, by: .merge))

    #expect(reply == .json(WorktreeUpdateEntry(outcome: .updated, conflicts: [], pane: nil)))
    #expect(await harness.contains("origin/main", in: feature))
  }

  @Test func anUpdateRequestOverUncommittedChangesIsRefusedNamingThem() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureBehindOrigin()
    try "edited\n".write(
      to: feature.path.appendingPathComponent("feature.txt"),
      atomically: true,
      encoding: .utf8,
    )
    let id = ControlID.worktree(feature.id)

    let reply = await harness.model.answer(Self.update(feature, by: .merge, force: true))

    #expect(reply == .refused(.uncommittedChanges(id: id, changes: ["M feature.txt"])))
    #expect(harness.model.presentedError == nil)
  }

  @Test func aRebaseRequestOfAPushedBranchIsRefusedUnlessItMayRewriteIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureBehindOrigin()
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "feature"], in: feature.path)
    let id = ControlID.worktree(feature.id)

    #expect(
      await harness.model.answer(Self.update(feature, by: .rebase))
        == .refused(.rewritesPushedBranch(id: id))
    )
    #expect(harness.model.pendingBaseUpdate == nil)

    let reply = await harness.model.answer(
      Self.update(feature, by: .rebase, allowsRewritingPushedBranch: true)
    )
    #expect(reply == .json(WorktreeUpdateEntry(outcome: .updated, conflicts: [], pane: nil)))
  }

  @Test func anUpdateRequestOverAWorkingAgentIsRefusedUnlessForced() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureBehindOrigin()
    _ = try harness.openAgentTab(in: feature, working: true)

    #expect(
      await harness.model.answer(Self.update(feature, by: .merge)) == .refused(.agentWorking)
    )
    #expect(harness.model.pendingBaseUpdate == nil)

    let reply = await harness.model.answer(Self.update(feature, by: .merge, force: true))
    #expect(reply == .json(WorktreeUpdateEntry(outcome: .updated, conflicts: [], pane: nil)))
  }

  @Test func anUpdateRequestStoppedOnConflictsListsThemAndASecondIsRefused() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureBehindOrigin(conflicting: true)
    let id = ControlID.worktree(feature.id)

    let reply = await harness.model.answer(Self.update(feature, by: .rebase))

    #expect(
      reply == .json(WorktreeUpdateEntry(outcome: .conflicts, conflicts: ["README.md"], pane: nil))
    )
    let again = await harness.model.answer(Self.update(feature, by: .merge))
    #expect(again == .refused(.unfinishedUpdate(id: id, method: .rebase)))
  }

  @Test func anUpdateRequestJustAfterARebaseEndedReadsTheBranchAgain() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureBehindOrigin(conflicting: true)
    _ = await harness.model.answer(Self.update(feature, by: .rebase))
    _ = try await harness.git.run(["rebase", "--abort"], in: feature.path)

    let reply = await harness.model.answer(Self.update(feature, by: .merge))

    #expect(
      reply == .json(WorktreeUpdateEntry(outcome: .conflicts, conflicts: ["README.md"], pane: nil))
    )
  }

  @Test func anUpdateRequestOnTheDefaultBranchItselfIsRefused() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    _ = try await harness.featureBehindOrigin()
    let main = try #require(harness.worktree(onBranch: "main"))
    let id = ControlID.worktree(main.id)

    #expect(
      await harness.model.answer(Self.update(main, by: .merge))
        == .refused(.baseUpdateUnavailable(id: id))
    )
  }

  @Test func anUpdateRequestOverAStoppedCherryPickNamesIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureBehindOrigin(conflicting: true)
    _ = try? await harness.git.run(["cherry-pick", "origin/main"], in: feature.path)

    let reply = await harness.model.answer(Self.update(feature, by: .merge))

    #expect(reply == .refused(.pickingCommits(id: ControlID.worktree(feature.id))))
  }

  @Test func changesMadeDuringTheFetchAreRefusedWithTheFilesAsData() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureBehindOrigin()
    let edited = feature.path.appendingPathComponent("agent-notes.md")
    try harness.wrapGit(in: #"[ "$1" = fetch ] && echo edit > '\#(edited.path)'"#)

    let reply = await harness.model.answer(Self.update(feature, by: .merge))

    #expect(
      reply
        == .refused(
          .uncommittedChanges(id: ControlID.worktree(feature.id), changes: ["? agent-notes.md"])
        )
    )
  }
}
