import Foundation
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit

extension AppModelControlWorktreesTests {
  @Test func aWorktreeIsRemovedWithNoDialogAndTheMainCheckoutIsRefused() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.setTrashesRemovedWorktrees(false)
    _ = await harness.model.answer(.newWorktree(order("feat/gone", in: harness)))
    let created = try #require(harness.worktree(onBranch: "feat/gone"))

    let reply = await harness.model.answer(
      .removeWorktree(
        WorktreeRemovalOrder(
          worktreeID: ControlID.worktree(created.id),
          deletesBranch: true,
          forcesBranchDeletion: false,
          force: false,
        )
      )
    )

    #expect(reply == .done)
    #expect(harness.model.pendingWorktreeRemoval == nil)
    #expect(harness.worktree(onBranch: "feat/gone") == nil)
    #expect(!FileManager.default.fileExists(atPath: created.path.path))
    let main = ControlID.worktree(harness.project.id)
    #expect(
      await harness.model.answer(
        .removeWorktree(
          WorktreeRemovalOrder(
            worktreeID: main,
            deletesBranch: false,
            forcesBranchDeletion: false,
            force: true,
          )
        )
      )
        == .refused(.worktreeNotRemovable(id: main))
    )
  }

  @Test func aBranchGitKeepsOnARemovalIsRefusedInTheAlertsWordsWithNoAlertLeftUp() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.setTrashesRemovedWorktrees(false)
    _ = await harness.model.answer(.newWorktree(order("feat/kept", in: harness)))
    let created = try #require(harness.worktree(onBranch: "feat/kept"))
    try await TestRepository.commit(
      "only here",
      files: ["kept.txt": "x"],
      in: created.path,
      using: harness.git,
    )

    let reply = await harness.model.answer(
      .removeWorktree(
        WorktreeRemovalOrder(
          worktreeID: ControlID.worktree(created.id),
          deletesBranch: true,
          forcesBranchDeletion: false,
          force: false,
        )
      )
    )

    guard case .alert? = reply.refusal else {
      Issue.record("not an alert: \(reply)")
      return
    }
    #expect(harness.model.presentedError == nil)
    #expect(try await harness.branches().contains("feat/kept"))
  }

  @Test func aForcedBranchDeletionDeletesABranchGitWouldKeepAndRaisesNoAlert() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.setTrashesRemovedWorktrees(false)
    _ = await harness.model.answer(.newWorktree(order("feat/kept", in: harness)))
    let created = try #require(harness.worktree(onBranch: "feat/kept"))
    try await TestRepository.commit(
      "only here",
      files: ["kept.txt": "x"],
      in: created.path,
      using: harness.git,
    )
    let users = PresentedError(title: "Users", message: "Up before the removal")
    harness.model.presentedError = users

    let reply = await harness.model.answer(
      .removeWorktree(
        WorktreeRemovalOrder(
          worktreeID: ControlID.worktree(created.id),
          deletesBranch: true,
          forcesBranchDeletion: true,
          force: false,
        )
      )
    )

    #expect(reply == .done)
    #expect(harness.worktree(onBranch: "feat/kept") == nil)
    #expect(try await !harness.branches().contains("feat/kept"))
    #expect(harness.model.presentedError?.id == users.id)
  }

  @Test func aForcePastAWorkingAgentStillLeavesABranchGitWouldKeep() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.setTrashesRemovedWorktrees(false)
    _ = await harness.model.answer(.newWorktree(order("feat/kept", in: harness)))
    let created = try #require(harness.worktree(onBranch: "feat/kept"))
    try await TestRepository.commit(
      "only here",
      files: ["kept.txt": "x"],
      in: created.path,
      using: harness.git,
    )

    let reply = await harness.model.answer(
      .removeWorktree(
        WorktreeRemovalOrder(
          worktreeID: ControlID.worktree(created.id),
          deletesBranch: true,
          forcesBranchDeletion: false,
          force: true,
        )
      )
    )

    guard case .alert? = reply.refusal else {
      Issue.record("not an alert: \(reply)")
      return
    }
    #expect(try await harness.branches().contains("feat/kept"))
  }

  @Test func aHooksVetoReachesTheCommandLineInItsOwnWords() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.setTrashesRemovedWorktrees(false)
    _ = await harness.model.answer(.newWorktree(order("feat/kept", in: harness)))
    let created = try #require(harness.worktree(onBranch: "feat/kept"))
    await harness.model.stageHandles.setupTask(of: created.id)?.value
    harness.model.setSettings(
      ProjectSettings(preDeleteHook: "echo still in use >&2; exit 1"),
      for: harness.project,
    )
    let id = ControlID.worktree(created.id)

    let reply = await harness.model.answer(
      .removeWorktree(
        WorktreeRemovalOrder(
          worktreeID: id,
          deletesBranch: false,
          forcesBranchDeletion: false,
          force: false,
        )
      )
    )

    guard case .removalVetoed(let vetoed, let message)? = reply.refusal else {
      Issue.record("not a veto: \(reply)")
      return
    }
    #expect(vetoed == id)
    #expect(message.contains("still in use"), "\(message)")
    #expect(harness.worktree(onBranch: "feat/kept") != nil)
  }

  @Test func anAlertAnotherRaisesDuringARefusedRemovalStaysUpAndIsNotItsReason() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.setTrashesRemovedWorktrees(false)
    _ = await harness.model.answer(.newWorktree(order("feat/kept", in: harness)))
    let created = try #require(harness.worktree(onBranch: "feat/kept"))
    await harness.model.stageHandles.setupTask(of: created.id)?.value
    harness.model.setSettings(
      ProjectSettings(preDeleteHook: "sleep 1; exit 1"),
      for: harness.project,
    )
    let id = ControlID.worktree(created.id)

    let removal = Task {
      await harness.model.answer(
        .removeWorktree(
          WorktreeRemovalOrder(
            worktreeID: id,
            deletesBranch: false,
            forcesBranchDeletion: false,
            force: false,
          )
        )
      )
    }
    try await waitUntil(
      { harness.model.worktreeOperations[created.id]?.stage == .preDeleteHook },
      seconds: 15,
    )
    let other = PresentedError(title: "Elsewhere", message: "Not the removal's")
    harness.model.presentedError = other
    let reply = await removal.value

    guard case .removalVetoed? = reply.refusal else {
      Issue.record("not the veto: \(reply)")
      return
    }
    #expect(harness.model.presentedError?.id == other.id)
  }
}
