import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit

@Suite(.serialized) @MainActor
struct AppModelWorktreeRemovalTests {
  @Test func removalShowsItsStageInThePaneUntilItEnds() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    await harness.model.createWorktree(
      branch: "going", basedOn: nil, createsBranch: true, in: harness.project)
    let worktree = try #require(harness.worktree(onBranch: "going"))
    harness.model.setSettings(ProjectSettings(preDeleteHook: "sleep 1"), for: harness.project)
    #expect(harness.model.liveTerminalCount == 1)

    let removal = Task { await harness.model.removeWorktree(worktree) }
    var seen: Set<WorktreeOperation.Stage> = []
    try await waitUntil(
      {
        guard let stage = harness.model.worktreeOperations[worktree.id]?.stage else {
          return !seen.isEmpty
        }
        seen.insert(stage)
        return false
      }, seconds: 15)
    await removal.value

    #expect(seen.contains(.preDeleteHook), "the hook was named while it ran: \(seen)")
    #expect(harness.model.worktreeOperations.isEmpty)
    #expect(harness.worktree(onBranch: "going") == nil)
    #expect(harness.model.liveTerminalCount == 0)
  }

  @Test func aFailingPreDeleteHookLeavesTheWorktreeAndItsShells() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    await harness.model.createWorktree(
      branch: "kept", basedOn: nil, createsBranch: true, in: harness.project)
    let worktree = try #require(harness.worktree(onBranch: "kept"))
    harness.model.setSettings(ProjectSettings(preDeleteHook: "exit 1"), for: harness.project)

    harness.model.presentedError = nil
    await harness.model.removeWorktree(worktree)

    #expect(
      harness.model.presentedError == nil, "the veto is shown in the pane, with no Remove Anyway")
    let refused = try #require(harness.model.worktreeOperations[worktree.id])
    #expect(!refused.isRunning && refused.stage == .preDeleteHook)
    #expect(refused.title == "The pre-delete hook refused the removal")
    #expect(harness.worktree(onBranch: "kept") != nil)
    #expect(harness.model.liveTerminalCount == 1, "the shells were never closed")
    #expect(FileManager.default.fileExists(atPath: worktree.path.path))

    harness.model.dismissOperationFailure(of: worktree)
    #expect(harness.model.worktreeOperations.isEmpty, "the pane shows the terminals again")
    #expect(harness.model.liveTerminalCount == 1)
  }

  @Test func removingAWorktreeClosesItsShellsAndDropsItsTabs() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    await harness.model.createWorktree(
      branch: "gone", basedOn: nil, createsBranch: true, in: harness.project)
    let worktree = try #require(harness.worktree(onBranch: "gone"))
    harness.model.newTab()
    #expect(harness.model.liveTerminalCount == 2)

    await harness.model.removeWorktree(worktree)

    #expect(harness.model.presentedError == nil)
    #expect(harness.worktree(onBranch: "gone") == nil)
    #expect(harness.model.workspace.tabs(in: worktree.id).isEmpty)
    #expect(harness.model.workspace.sessions(in: worktree.id).isEmpty)
    #expect(harness.engine.closed.count == 2)
    #expect(harness.model.liveTerminalCount == 0)
    #expect(harness.model.workspace.selectedWorktreeID == nil)
    #expect(!FileManager.default.fileExists(atPath: worktree.path.path))
    #expect(
      harness.watcher.watched.map(\.lastPathComponent) == [".git"],
      "git deletes the worktrees folder with its last entry, so the watch falls back")
  }

  @Test func aRemovedWorktreeGoesToTheTrashWithItsUncommittedWork() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    await harness.model.createWorktree(
      branch: "dirty", basedOn: nil, createsBranch: true, in: harness.project)
    let worktree = try #require(harness.worktree(onBranch: "dirty"))
    try "uncommitted\n".write(
      to: worktree.path.appendingPathComponent("work.txt"), atomically: true, encoding: .utf8)
    await harness.model.refreshStatuses()
    let pending = PendingWorktreeRemoval(
      worktree: worktree, branchHandling: .decided(deletesBranch: false))
    #expect(
      pending.message(warning: harness.model.worktreeRemovalWarning(for: pending))
        .contains("1 changed file, kept in the Trash"))

    await harness.model.removeWorktree(worktree)

    #expect(harness.model.presentedError == nil)
    #expect(harness.platform.trashed == [worktree.path])
    #expect(harness.worktree(onBranch: "dirty") == nil, "pruned from git and the sidebar")
    #expect(
      FileManager.default.fileExists(
        atPath: harness.platform.trash!.appendingPathComponent("dirty/work.txt").path))
    #expect(harness.model.liveTerminalCount == 0)
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

  @Test func withTheTrashOffARemovedWorktreeIsDeletedOutright() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.setTrashesRemovedWorktrees(false)
    await harness.model.createWorktree(
      branch: "gone", basedOn: nil, createsBranch: true, in: harness.project)
    let worktree = try #require(harness.worktree(onBranch: "gone"))
    try "uncommitted\n".write(
      to: worktree.path.appendingPathComponent("work.txt"), atomically: true, encoding: .utf8)
    await harness.model.refreshStatuses()
    let pending = PendingWorktreeRemoval(
      worktree: worktree, branchHandling: .decided(deletesBranch: false), trashes: false)
    #expect(
      harness.model.worktreeRemovalWarning(for: pending)?.contains("deleted with the directory")
        == true)

    await harness.model.removeWorktree(worktree)

    #expect(harness.model.presentedError == nil)
    #expect(harness.platform.trashed.isEmpty)
    #expect(!FileManager.default.fileExists(atPath: worktree.path.path))
    #expect(harness.worktree(onBranch: "gone") == nil)
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
    await harness.model.removeAsConfirmed(pending, deletingBranch: false)

    #expect(harness.platform.trashed == [worktree.path])
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
    let branches = try await harness.localBranches()
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

  @Test func removingWithTheBranchDeletesItAndAnUnmergedOneOffersTheForcedForm() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    await harness.model.createWorktree(
      branch: "merged", basedOn: nil, createsBranch: true, in: harness.project)
    let merged = try #require(harness.worktree(onBranch: "merged"))

    await harness.model.removeWorktree(merged, deletingBranch: true)

    #expect(harness.model.presentedError == nil)
    #expect(harness.worktree(onBranch: "merged") == nil)
    let branches = try await harness.localBranches()
    #expect(!branches.contains("merged"))

    await harness.model.createWorktree(
      branch: "ahead", basedOn: nil, createsBranch: true, in: harness.project)
    let ahead = try #require(harness.worktree(onBranch: "ahead"))
    try "work\n".write(
      to: ahead.path.appendingPathComponent("w.txt"), atomically: true, encoding: .utf8)
    _ = try await harness.git.run(["add", "."], in: ahead.path)
    _ = try await harness.git.run(["commit", "-q", "-m", "ahead"], in: ahead.path)

    await harness.model.removeWorktree(ahead, deletingBranch: true)

    let refused = try #require(harness.model.presentedError)
    #expect(refused.title == "Worktree removed, but branch ahead was not deleted")
    #expect(refused.retry?.label == "Force Deletion")
    #expect(harness.worktree(onBranch: "ahead") == nil, "the worktree itself went")
    #expect(harness.model.liveTerminalCount == 0)

    await refused.retry?.action()

    let after = try await harness.localBranches()
    #expect(!after.contains("ahead"))
  }

  @Test func aFailingPostDeleteHookKeepsTheBranchAndSaysSo() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    await harness.model.createWorktree(
      branch: "hooked", basedOn: nil, createsBranch: true, in: harness.project)
    let worktree = try #require(harness.worktree(onBranch: "hooked"))
    harness.model.setSettings(ProjectSettings(postDeleteHook: "exit 2"), for: harness.project)

    await harness.model.removeWorktree(worktree, deletingBranch: true)

    #expect(harness.model.presentedError?.title == "Worktree removed, but its hook failed")
    #expect(harness.model.presentedError?.message.hasSuffix("The branch hooked was kept.") == true)
    #expect(harness.worktree(onBranch: "hooked") == nil)
    let branches = try await harness.localBranches()
    #expect(branches.contains("hooked"), "a hook that pushes would have wanted it there")
  }

  @Test func cancelOnAPreDeleteHookLeavesTheWorktreeQuietly() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    await harness.model.createWorktree(
      branch: "kept", basedOn: nil, createsBranch: true, in: harness.project)
    let worktree = try #require(harness.worktree(onBranch: "kept"))
    harness.model.setSettings(ProjectSettings(preDeleteHook: "sleep 30"), for: harness.project)
    harness.model.setConfirmsWorktreeRemoval(false)
    harness.model.setDeletesBranchWithWorktree(true)

    harness.model.requestWorktreeRemoval(of: worktree)
    try await waitUntil { harness.model.worktreeOperations[worktree.id]?.stage == .preDeleteHook }
    #expect(harness.model.worktreeOperations[worktree.id]?.stage == .preDeleteHook)
    harness.model.cancelStage(of: worktree)
    await harness.awaitOperationEnd(on: worktree.id)

    #expect(harness.model.worktreeOperations[worktree.id] == nil)
    #expect(harness.model.presentedError == nil)
    #expect(harness.worktree(onBranch: "kept") != nil && harness.model.liveTerminalCount == 1)
  }

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

  /// The main worktree is the repository. Only a sidebar condition three
  /// modules away kept it off this call, and the trash step would bin `.git`.
  @Test func removingTheMainWorktreeIsRefusedBeforeAnythingRuns() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let marker = harness.root.appendingPathComponent("delete-hook-ran")
    harness.model.setSettings(
      ProjectSettings(preDeleteHook: "touch \(marker.path)"), for: harness.project)
    let main = try #require(harness.worktree(onBranch: "main"))
    #expect(main.isPrimary)

    await harness.model.removeWorktree(main)

    #expect(!FileManager.default.fileExists(atPath: marker.path), "the hook did not run")
    #expect(harness.platform.trashed.isEmpty, "and nothing went to the Trash")
    #expect(FileManager.default.fileExists(atPath: main.path.path))
    #expect(harness.model.presentedError != nil)
  }

  @Test func aLockedWorktreeIsForgottenLockAndAll() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    await harness.model.createWorktree(
      branch: "locked", basedOn: nil, createsBranch: true, in: harness.project)
    var worktree = try #require(harness.worktree(onBranch: "locked"))
    _ = try await harness.git.run(
      ["worktree", "lock", worktree.path.path], in: harness.project.path)
    await harness.model.refreshWorktrees(of: harness.project)
    worktree = try #require(harness.worktree(onBranch: "locked"))
    #expect(worktree.isLocked)

    await harness.model.removeWorktree(worktree)

    #expect(harness.model.presentedError == nil)
    #expect(harness.worktree(onBranch: "locked") == nil, "no record left behind")
    #expect(harness.platform.trashed == [worktree.path])
  }
}
