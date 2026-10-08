import Foundation
import TestScratch
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
      "the branch question is still open")
    #expect(harness.model.pendingWorktreeRemoval?.choices.count == 2)

    harness.model.pendingWorktreeRemoval = nil
    harness.model.setDeletesBranchWithWorktree(true)
    await harness.model.requestWorktreeRemoval(of: harness.feature)?.value
    #expect(
      harness.model.pendingWorktreeRemoval == nil,
      "goes straight to removal, which needs git and so no-ops here")

    harness.model.setConfirmsWorktreeRemoval(true)
    await harness.model.requestWorktreeRemoval(of: harness.feature)?.value
    #expect(harness.model.pendingWorktreeRemoval?.branchHandling == .decided(deletesBranch: true))
    #expect(harness.model.pendingWorktreeRemoval?.choices.count == 1)

    harness.model.pendingWorktreeRemoval = nil
    harness.model.setTrashesRemovedWorktrees(false)
    await harness.model.requestWorktreeRemoval(of: harness.feature)?.value
    #expect(
      harness.model.pendingWorktreeRemoval?.message(warning: nil).hasPrefix("Deletes ") == true)
  }

  @Test func answeringTheDialogWithAButtonRemovesAsThatButtonSays() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    await harness.model.createWorktree(
      branch: "answered", basedOn: nil, createsBranch: true, in: harness.project)
    let worktree = try #require(harness.worktree(onBranch: "answered"))
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
      worktree: harness.feature, branchHandling: .offersBoth, trashes: true)
    harness.model.pendingWorktreeRemoval = pending

    #expect(harness.model.answerWorktreeRemoval(pending, choice: nil) == nil)
    #expect(harness.model.answerWorktreeRemoval(pending, choice: pending.choices.count) == nil)
    #expect(harness.model.pendingWorktreeRemoval == nil)
    #expect(harness.model.workspace.worktree(harness.feature.id) != nil)
  }

  @Test func aConfirmedRemovalKeepsTheTrashTheDialogNamedThoughTheSettingChanged() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    await harness.model.createWorktree(
      branch: "kept", basedOn: nil, createsBranch: true, in: harness.project)
    let worktree = try #require(harness.worktree(onBranch: "kept"))
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
      worktree: harness.feature, branchHandling: .decided(deletesBranch: false), trashes: true,
      hasUnreadChanges: true)

    #expect(
      harness.model.worktreeRemovalWarning(for: pending)?.contains("kept in the Trash") == true)
  }
}
