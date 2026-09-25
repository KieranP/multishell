import Foundation
import MultishellCore
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite(.serialized) @MainActor
struct AppModelWorktreeRemovalTests {
  @Test func removalShowsItsStageInThePaneUntilItEnds() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "going", basedOn: nil, createBranch: true, in: h.project)
    let worktree = try #require(h.worktree(onBranch: "going"))
    h.model.updateSettings(ProjectSettings(preDeleteHook: "sleep 1"), for: h.project)
    #expect(h.model.liveTerminalCount == 1)

    let removal = Task { await h.model.removeWorktree(worktree) }
    var seen: Set<WorktreeOperation.Step> = []
    let deadline = ContinuousClock.now + .seconds(15)
    while ContinuousClock.now < deadline, !seen.contains(.removingWorktree) {
      if let step = h.model.worktreeOperations[worktree.id]?.step { seen.insert(step) }
      try await Task.sleep(for: .milliseconds(20))
    }
    await removal.value

    #expect(seen.contains(.preDeleteHook), "the hook was named while it ran: \(seen)")
    #expect(h.model.worktreeOperations.isEmpty)
    #expect(h.worktree(onBranch: "going") == nil)
    #expect(h.model.liveTerminalCount == 0)
  }

  @Test func aFailingPreDeleteHookLeavesTheWorktreeAndItsShells() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "kept", basedOn: nil, createBranch: true, in: h.project)
    let worktree = try #require(h.worktree(onBranch: "kept"))
    h.model.updateSettings(ProjectSettings(preDeleteHook: "exit 1"), for: h.project)

    h.model.presentedError = nil
    await h.model.removeWorktree(worktree)

    #expect(h.model.presentedError == nil, "the veto is shown in the pane, with no Remove Anyway")
    let refused = try #require(h.model.worktreeOperations[worktree.id])
    #expect(!refused.isRunning && refused.step == .preDeleteHook)
    #expect(refused.title == "The pre-delete hook refused the removal")
    #expect(h.worktree(onBranch: "kept") != nil)
    #expect(h.model.liveTerminalCount == 1, "the shells were never closed")
    #expect(FileManager.default.fileExists(atPath: worktree.path.path))

    h.model.dismissOperationFailure(of: worktree)
    #expect(h.model.worktreeOperations.isEmpty, "the pane shows the terminals again")
    #expect(h.model.liveTerminalCount == 1)
  }

  @Test func removingAWorktreeClosesItsShellsAndDropsItsTabs() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "gone", basedOn: nil, createBranch: true, in: h.project)
    let worktree = try #require(h.worktree(onBranch: "gone"))
    h.model.newTab()
    #expect(h.model.liveTerminalCount == 2)

    await h.model.removeWorktree(worktree)

    #expect(h.model.presentedError == nil)
    #expect(h.worktree(onBranch: "gone") == nil)
    #expect(h.model.workspace.tabs(in: worktree.id).isEmpty)
    #expect(h.model.workspace.sessions(in: worktree.id).isEmpty)
    #expect(h.engine.closed.count == 2)
    #expect(h.model.liveTerminalCount == 0)
    #expect(h.model.workspace.selectedWorktreeID == nil)
    #expect(!FileManager.default.fileExists(atPath: worktree.path.path))
    #expect(
      h.watcher.watched.map(\.lastPathComponent) == [".git"],
      "git deletes the worktrees folder with its last entry, so the watch falls back")
  }

  @Test func aRemovedWorktreeGoesToTheTrashWithItsUncommittedWork() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "dirty", basedOn: nil, createBranch: true, in: h.project)
    let worktree = try #require(h.worktree(onBranch: "dirty"))
    try "uncommitted\n".write(
      to: worktree.path.appendingPathComponent("work.txt"), atomically: true, encoding: .utf8)
    await h.model.refreshStatuses()
    let pending = PendingWorktreeRemoval(
      worktree: worktree, branchHandling: .decided(deletes: false))
    #expect(
      pending.message(warning: h.model.worktreeRemovalWarning(for: worktree))
        .contains("1 changed file, kept in the Trash"))

    await h.model.removeWorktree(worktree)

    #expect(h.model.presentedError == nil)
    #expect(h.platform.trashed == [worktree.path])
    #expect(h.worktree(onBranch: "dirty") == nil, "pruned from git and the sidebar")
    #expect(
      FileManager.default.fileExists(
        atPath: h.platform.trash!.appendingPathComponent("dirty/work.txt").path))
    #expect(h.model.liveTerminalCount == 0)
  }

  @Test func withTheTrashOffARemovedWorktreeIsDeletedOutright() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    h.model.setTrashesRemovedWorktrees(false)
    await h.model.createWorktree(branch: "gone", basedOn: nil, createBranch: true, in: h.project)
    let worktree = try #require(h.worktree(onBranch: "gone"))
    try "uncommitted\n".write(
      to: worktree.path.appendingPathComponent("work.txt"), atomically: true, encoding: .utf8)
    await h.model.refreshStatuses()
    #expect(
      h.model.worktreeRemovalWarning(for: worktree)?.contains("deleted with the directory") == true)

    await h.model.removeWorktree(worktree)

    #expect(h.model.presentedError == nil)
    #expect(h.platform.trashed.isEmpty)
    #expect(!FileManager.default.fileExists(atPath: worktree.path.path))
    #expect(h.worktree(onBranch: "gone") == nil)
  }

  @Test func aConfirmedRemovalKeepsTheTrashTheDialogNamedThoughTheSettingChanged() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "kept", basedOn: nil, createBranch: true, in: h.project)
    let worktree = try #require(h.worktree(onBranch: "kept"))
    await h.model.requestWorktreeRemoval(of: worktree)?.value
    let pending = try #require(h.model.pendingWorktreeRemoval)
    #expect(pending.message(warning: nil).hasPrefix("Moves "))

    h.model.setTrashesRemovedWorktrees(false)
    await h.model.confirmWorktreeRemoval(pending, deletingBranch: false)

    #expect(h.platform.trashed == [worktree.path])
  }

  @Test func removingWithTheBranchDeletesItAndAnUnmergedOneOffersTheForcedForm() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "merged", basedOn: nil, createBranch: true, in: h.project)
    let merged = try #require(h.worktree(onBranch: "merged"))

    await h.model.removeWorktree(merged, deletingBranch: true)

    #expect(h.model.presentedError == nil)
    #expect(h.worktree(onBranch: "merged") == nil)
    let branches = try await h.git.run(
      ["for-each-ref", "--format=%(refname:short)", "refs/heads"], in: h.project.path)
    #expect(!branches.contains("merged"))

    await h.model.createWorktree(branch: "ahead", basedOn: nil, createBranch: true, in: h.project)
    let ahead = try #require(h.worktree(onBranch: "ahead"))
    try "work\n".write(
      to: ahead.path.appendingPathComponent("w.txt"), atomically: true, encoding: .utf8)
    _ = try await h.git.run(["add", "."], in: ahead.path)
    _ = try await h.git.run(["commit", "-q", "-m", "ahead"], in: ahead.path)

    await h.model.removeWorktree(ahead, deletingBranch: true)

    let refused = try #require(h.model.presentedError)
    #expect(refused.title == "Worktree removed, but branch ahead was not deleted")
    #expect(refused.retry?.label == "Force Deletion")
    #expect(h.worktree(onBranch: "ahead") == nil, "the worktree itself went")
    #expect(h.model.liveTerminalCount == 0)

    await refused.retry?.action()

    let after = try await h.git.run(
      ["for-each-ref", "--format=%(refname:short)", "refs/heads"], in: h.project.path)
    #expect(!after.contains("ahead"))
  }

  @Test func aFailingPostDeleteHookKeepsTheBranchAndSaysSo() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "hooked", basedOn: nil, createBranch: true, in: h.project)
    let worktree = try #require(h.worktree(onBranch: "hooked"))
    h.model.updateSettings(ProjectSettings(postDeleteHook: "exit 2"), for: h.project)

    await h.model.removeWorktree(worktree, deletingBranch: true)

    #expect(h.model.presentedError?.title == "Worktree removed, but its hook failed")
    #expect(h.model.presentedError?.message.hasSuffix("The branch hooked was kept.") == true)
    #expect(h.worktree(onBranch: "hooked") == nil)
    let branches = try await h.git.run(
      ["for-each-ref", "--format=%(refname:short)", "refs/heads"], in: h.project.path)
    #expect(branches.contains("hooked"), "a hook that pushes would have wanted it there")
  }

  @Test func cancelOnAPreDeleteHookLeavesTheWorktreeQuietly() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "kept", basedOn: nil, createBranch: true, in: h.project)
    let worktree = try #require(h.worktree(onBranch: "kept"))
    h.model.updateSettings(ProjectSettings(preDeleteHook: "sleep 30"), for: h.project)
    h.model.setConfirmsWorktreeRemoval(false)
    h.model.setDeletesBranchWithWorktree(true)

    h.model.requestWorktreeRemoval(of: worktree)
    try await waitUntil { h.model.worktreeOperations[worktree.id]?.step == .preDeleteHook }
    #expect(h.model.worktreeOperations[worktree.id]?.step == .preDeleteHook)
    h.model.cancelStage(of: worktree)
    await h.awaitOperationEnd(on: worktree.id)

    #expect(h.model.worktreeOperations[worktree.id] == nil)
    #expect(h.model.presentedError == nil)
    #expect(h.worktree(onBranch: "kept") != nil && h.model.liveTerminalCount == 1)
  }

  @Test func deletingAWorktreeOutrightLeavesWhatItsLinksPointAt() async throws {
    let main = try Scratch.directory("linked-main")
    let modules = main.appendingPathComponent("node_modules")
    try FileManager.default.createDirectory(at: modules, withIntermediateDirectories: true)
    try "x".write(to: modules.appendingPathComponent("a.js"), atomically: true, encoding: .utf8)
    let worktree = try Scratch.directory("linked-worktree")
    try FileManager.default.createSymbolicLink(
      at: worktree.appendingPathComponent("node_modules"), withDestinationURL: modules)

    try await AppModel<FakeSurface>.deleteDirectory(worktree)

    #expect(!FileManager.default.fileExists(atPath: worktree.path))
    #expect(FileManager.default.fileExists(atPath: modules.appendingPathComponent("a.js").path))
  }

  @Test func removingTheMainWorktreeIsRefusedBeforeAnyDialog() {
    let h = Harness()
    h.model.requestWorktreeRemoval(of: h.main)
    #expect(h.model.pendingWorktreeRemoval == nil)
    #expect(h.model.worktreeOperations.isEmpty)
    #expect(!h.main.isRemovable)
    #expect(h.feature.isRemovable)
  }

  @Test func removalAsksUnlessTheGlobalSettingsSettleBothTheWorktreeAndTheBranch() async {
    let h = Harness()
    await h.model.requestWorktreeRemoval(of: h.feature)?.value
    #expect(h.model.pendingWorktreeRemoval?.id == h.feature.id)
    #expect(h.model.pendingWorktreeRemoval?.choices.count == 2)

    h.model.pendingWorktreeRemoval = nil
    h.model.setConfirmsWorktreeRemoval(false)
    await h.model.requestWorktreeRemoval(of: h.feature)?.value
    #expect(h.model.pendingWorktreeRemoval?.id == h.feature.id, "the branch question is still open")
    #expect(h.model.pendingWorktreeRemoval?.choices.count == 2)

    h.model.pendingWorktreeRemoval = nil
    h.model.setDeletesBranchWithWorktree(true)
    await h.model.requestWorktreeRemoval(of: h.feature)?.value
    #expect(
      h.model.pendingWorktreeRemoval == nil,
      "goes straight to removal, which needs git and so no-ops here")

    h.model.setConfirmsWorktreeRemoval(true)
    await h.model.requestWorktreeRemoval(of: h.feature)?.value
    #expect(h.model.pendingWorktreeRemoval?.branchHandling == .decided(deletes: true))
    #expect(h.model.pendingWorktreeRemoval?.choices.count == 1)

    h.model.pendingWorktreeRemoval = nil
    h.model.setTrashesRemovedWorktrees(false)
    await h.model.requestWorktreeRemoval(of: h.feature)?.value
    #expect(h.model.pendingWorktreeRemoval?.message(warning: nil).hasPrefix("Deletes ") == true)
  }
}
