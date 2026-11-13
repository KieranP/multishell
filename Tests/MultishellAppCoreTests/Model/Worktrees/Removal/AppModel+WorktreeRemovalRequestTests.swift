import Foundation
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit

@Suite(.serialized) @MainActor
struct AppModelWorktreeRemovalRequestTests {
  @Test func removingTheMainWorktreeIsRefusedBeforeAnyDialog() {
    let harness = Harness()
    harness.model.requestWorktreeRemoval(of: harness.main)
    #expect(harness.model.pendingWorktreeRemoval == nil)
    #expect(harness.model.worktreeOperations.isEmpty)
    #expect(!harness.main.isRemovable)
    #expect(harness.feature.isRemovable)
  }

  @Test func aWorktreeGitIsStillCheckingOutIsNotRemoved() async {
    let harness = Harness()
    var checkingOut = harness.feature
    checkingOut.isInitializing = true
    harness.store.replaceWorktrees(
      [harness.main, checkingOut],
      forProject: harness.main.projectID,
    )

    #expect(!harness.model.mayRemove(checkingOut))
    await harness.model.requestWorktreeRemoval(of: checkingOut)?.value
    #expect(harness.model.pendingWorktreeRemoval == nil)
  }

  @Test func removalAsksUnlessTheGlobalSettingsSettleBothTheWorktreeAndTheBranch() async {
    let harness = Harness()
    await harness.model.requestWorktreeRemoval(of: harness.feature)?.value
    #expect(harness.model.pendingWorktreeRemoval?.id == harness.feature.id)
    #expect(harness.model.pendingWorktreeRemoval?.choices.count == 2)

    harness.model.pendingWorktreeRemoval = nil
    harness.model.setConfirmsWorktreeRemoval(false)
    await harness.model.requestWorktreeRemoval(of: harness.feature)?.value
    #expect(
      harness.model.pendingWorktreeRemoval?.id == harness.feature.id,
      "the branch question is still open",
    )
    #expect(harness.model.pendingWorktreeRemoval?.choices.count == 2)

    harness.model.pendingWorktreeRemoval = nil
    harness.model.setDeletesBranchWithWorktree(true)
    await harness.model.requestWorktreeRemoval(of: harness.feature)?.value
    #expect(
      harness.model.pendingWorktreeRemoval == nil,
      "goes straight to removal, which needs git and so no-ops here",
    )

    harness.model.setConfirmsWorktreeRemoval(true)
    await harness.model.requestWorktreeRemoval(of: harness.feature)?.value
    #expect(harness.model.pendingWorktreeRemoval?.branchHandling == .decided(deletesBranch: true))
    #expect(harness.model.pendingWorktreeRemoval?.choices.count == 1)

    harness.model.pendingWorktreeRemoval = nil
    harness.model.setTrashesRemovedWorktrees(false)
    await harness.model.requestWorktreeRemoval(of: harness.feature)?.value
    #expect(
      harness.model.pendingWorktreeRemoval?.message(warning: nil).hasPrefix("Deletes ") == true
    )
  }

  @Test func aDetachedWorktreeHoldingCommitsOnNoBranchIsAskedAboutWithConfirmationOff()
    async throws
  {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let worktree = try await harness.createWorktree(onBranch: "pinned")
    _ = try await harness.git.run(["checkout", "--detach"], in: worktree.path)
    try await TestRepository.commit(
      "adrift",
      files: ["adrift.txt": "work"],
      in: worktree.path,
      using: harness.git,
    )
    await harness.model.refreshWorktrees(of: harness.project)
    let detached = try #require(harness.model.workspace.worktree(worktree.id))
    harness.model.setConfirmsWorktreeRemoval(false)

    await harness.model.requestWorktreeRemoval(of: detached)?.value

    let pending = try #require(harness.model.pendingWorktreeRemoval)
    #expect(harness.model.worktreeRemovalWarning(for: pending)?.contains("1 commit") == true)
  }

  @Test func aDetachedWorktreeWhoseCommitsGitCannotCountIsAskedAbout() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let worktree = try await harness.createWorktree(onBranch: "pinned")
    _ = try await harness.git.run(["checkout", "--detach"], in: worktree.path)
    await harness.model.refreshWorktrees(of: harness.project)
    let detached = try #require(harness.model.workspace.worktree(worktree.id))
    try harness.wrapGit(in: #"case "$*" in *rev-list*--branches*) exit 128 ;; esac"#)
    harness.model.setConfirmsWorktreeRemoval(false)

    await harness.model.requestWorktreeRemoval(of: detached)?.value

    let pending = try #require(harness.model.pendingWorktreeRemoval)
    #expect(harness.model.worktreeRemovalWarning(for: pending)?.contains("could not count") == true)
  }

  @Test func aDetachedRemovalNeedingNoDialogStillRunsWhenAnotherIsAskedMeanwhile() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let pinned = try await harness.createWorktree(onBranch: "pinned")
    _ = try await harness.git.run(["checkout", "--detach"], in: pinned.path)
    let asked = try await harness.createWorktree(onBranch: "asked")
    await harness.model.refreshWorktrees(of: harness.project)
    let detached = try #require(harness.model.workspace.worktree(pinned.id))
    harness.model.setConfirmsWorktreeRemoval(false)

    let first = harness.model.requestWorktreeRemoval(of: detached)
    let second = harness.model.requestWorktreeRemoval(of: asked)
    await first?.value
    await second?.value
    try await harness.awaitOperationEnd(on: detached.id)

    #expect(harness.model.workspace.worktree(detached.id) == nil)
    #expect(harness.model.pendingWorktreeRemoval?.id == asked.id)
  }

  @Test func answeringTheDialogWithAButtonRemovesAsThatButtonSays() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let worktree = try await harness.createWorktree(onBranch: "answered")
    await harness.model.requestWorktreeRemoval(of: worktree)?.value
    let pending = try #require(harness.model.pendingWorktreeRemoval)
    let choice = try #require(pending.choices.indices.last)

    await harness.model.answerWorktreeRemoval(pending, choice: choice)?.value

    #expect(harness.model.pendingWorktreeRemoval == nil)
    #expect(harness.worktree(onBranch: "answered") == nil)
    let branches = try await harness.branches()
    #expect(branches.contains("answered") != pending.choices[choice].deletesBranch)
  }

  @Test func cancellingTheDialogTakesItDownAndRemovesNothing() {
    let harness = Harness()
    let pending = PendingWorktreeRemoval(
      worktree: harness.feature,
      branchHandling: .offersBoth,
      customName: nil,
      mergeState: .unknown,
      trashes: true,
      isStatusUnread: false,
    )
    harness.model.pendingWorktreeRemoval = pending

    #expect(harness.model.answerWorktreeRemoval(pending, choice: nil) == nil)
    #expect(harness.model.answerWorktreeRemoval(pending, choice: pending.choices.count) == nil)
    #expect(harness.model.pendingWorktreeRemoval == nil)
    #expect(harness.model.workspace.worktree(harness.feature.id) != nil)
  }

  @Test func aConfirmedRemovalKeepsTheTrashTheDialogNamedThoughTheSettingChanged() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let worktree = try await harness.createWorktree(onBranch: "kept")
    await harness.model.requestWorktreeRemoval(of: worktree)?.value
    let pending = try #require(harness.model.pendingWorktreeRemoval)
    #expect(pending.message(warning: nil).hasPrefix("Moves "))

    harness.model.setTrashesRemovedWorktrees(false)
    await harness.model.removeAsConfirmed(pending, deletesBranch: false)

    #expect(harness.platform.trashed == [worktree.path])
  }

  @Test func theWarningSaysWhereTheDialogSendsTheDirectoryNotWhereTheSettingNowDoes() {
    let harness = Harness()
    harness.model.setTrashesRemovedWorktrees(false)
    let pending = PendingWorktreeRemoval(
      worktree: harness.feature,
      branchHandling: .decided(deletesBranch: false),
      customName: nil,
      mergeState: .unknown,
      trashes: true,
      isStatusUnread: true,
    )

    #expect(
      harness.model.worktreeRemovalWarning(for: pending)?.contains("kept in the Trash") == true
    )
  }
}
