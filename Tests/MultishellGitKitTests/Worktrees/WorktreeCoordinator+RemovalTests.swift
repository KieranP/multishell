import Foundation
import MultishellProcess
import TestScratch
import TestSupport
import Testing

@testable import MultishellCore
@testable import MultishellGitKit

@Suite(.serialized)
struct WorktreeCoordinatorRemovalTests {
  @Test func removingKeepsTheBranch() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.coordinator.createThenRunPostCreate(
      branch: "keep", in: fixture.project, settings: fixture.worktreeSettings)
    let worktree = try await fixture.worktree(onBranch: "keep")

    try await fixture.coordinator.removeUnlinking(worktree, in: fixture.project)

    #expect(try await fixture.branches() == ["keep", "main"])
    #expect(!FileManager.default.fileExists(atPath: worktree.path.path))
  }

  @Test func aDirtyWorktreeIsHandedToTheTrashNotRefused() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = try await fixture.coordinator.createThenRunPostCreate(
      branch: "dirty", in: fixture.project, settings: fixture.worktreeSettings)
    try "uncommitted\n".write(
      to: path.appendingPathComponent("work.txt"), atomically: true, encoding: .utf8)
    let worktree = try await fixture.worktree(onBranch: "dirty")
    let bin = fixture.root.appendingPathComponent("bin", isDirectory: true)

    try await fixture.coordinator.remove(worktree, in: fixture.project, trash: moveToBin(bin))

    #expect(!FileManager.default.fileExists(atPath: path.path))
    #expect(
      FileManager.default.fileExists(atPath: bin.appendingPathComponent("dirty/work.txt").path))
    #expect(try await fixture.coordinator.git.list(fixture.project).count == 1)
  }

  @Test func aTrashedWorktreeIsHandedOverThenForgottenAndTheHooksStillRun() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    var project = fixture.project
    project.settings = ProjectSettings(postDeleteHook: "echo gone > deleted.txt")
    let path = try await fixture.coordinator.createThenRunPostCreate(
      branch: "dirty", in: project, settings: fixture.worktreeSettings)
    try "work\n".write(
      to: path.appendingPathComponent("wip.txt"), atomically: true, encoding: .utf8)
    let worktree = try await fixture.worktree(onBranch: "dirty", in: project)
    let bin = fixture.root.appendingPathComponent("bin", isDirectory: true)
    let steps = Recorder<WorktreeRemovalStep>()

    try await fixture.coordinator.remove(
      worktree, in: project, trash: moveToBin(bin),
      onStep: { steps.record($0) })

    #expect(steps.received == [.removingWorktree, .postDeleteHook])
    #expect(try await fixture.coordinator.git.list(project).count == 1, "forgotten")
    #expect(
      FileManager.default.fileExists(atPath: bin.appendingPathComponent("dirty/wip.txt").path),
      "the work is where the Trash put it")
    #expect(
      FileManager.default.fileExists(
        atPath: project.path.appendingPathComponent("deleted.txt").path))
    #expect(WorktreeRemovalStep.first(for: project) == .removingWorktree)
  }

  @Test func aTrashThatRefusesLeavesTheWorktreeRegisteredAndInPlace() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = try await fixture.coordinator.createThenRunPostCreate(
      branch: "kept", in: fixture.project, settings: fixture.worktreeSettings)
    let worktree = try await fixture.worktree(onBranch: "kept")

    await #expect(throws: TrashFailure.self) {
      try await fixture.coordinator.remove(
        worktree, in: fixture.project, trash: { _ in throw CocoaError(.fileWriteNoPermission) })
    }
    #expect(FileManager.default.fileExists(atPath: path.path))
    #expect(
      try await fixture.coordinator.git.list(fixture.project).count == 2, "nothing was pruned")
  }

  @Test func aRemovedWorktreeIsNoLongerListedAndThePostDeleteHookRunsInTheProject() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }

    var project = fixture.project
    project.settings = ProjectSettings(postDeleteHook: "echo gone > deleted.txt")
    let settings = fixture.worktreeSettings

    let coordinator = fixture.coordinator
    try await coordinator.createThenRunPostCreate(
      branch: "scratch", in: project, settings: settings)

    let worktree = try await fixture.worktree(onBranch: "scratch", in: project)
    try await coordinator.removeUnlinking(worktree, in: project)

    #expect(try await coordinator.git.list(project).count == 1)
    #expect(
      FileManager.default.fileExists(
        atPath: project.path.appendingPathComponent("deleted.txt").path))
  }

  @Test func removingCanDeleteTheBranchAfterThePostHookHasSeenIt() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    var project = fixture.project
    project.settings = ProjectSettings(
      postDeleteHook: "git rev-parse --verify \"$MULTISHELL_BRANCH\" > hook-saw-branch.txt")
    try await fixture.coordinator.createThenRunPostCreate(
      branch: "done", in: project, settings: fixture.worktreeSettings)
    let worktree = try await fixture.worktree(onBranch: "done", in: project)

    try await fixture.coordinator.removeUnlinking(worktree, deletingBranch: true, in: project)

    #expect(try await fixture.branches() == ["main"])
    let seen = try String(
      contentsOf: project.path.appendingPathComponent("hook-saw-branch.txt"), encoding: .utf8)
    #expect(!seen.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "the hook ran first")
  }

  @Test func aBranchWithItsOwnCommitsIsRefusedThenForced() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = try await fixture.coordinator.createThenRunPostCreate(
      branch: "unmerged", in: fixture.project, settings: fixture.worktreeSettings)
    try await TestRepository.commit(
      "unmerged", files: ["w.txt": "work\n"], in: path, using: fixture.runner)
    let worktree = try await fixture.worktree(onBranch: "unmerged")

    await #expect(throws: BranchDeletionFailure.self) {
      try await fixture.coordinator.removeUnlinking(
        worktree, deletingBranch: true, in: fixture.project)
    }

    #expect(
      try await fixture.coordinator.git.list(fixture.project).count == 1, "the worktree is gone")
    #expect(try await fixture.branches() == ["main", "unmerged"], "the branch is kept")

    try await fixture.coordinator.deleteBranch("unmerged", force: true, in: fixture.project)
    #expect(try await fixture.branches() == ["main"])
  }

  @Test func aDetachedWorktreeHasNoBranchToDelete() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.worktreeSettings.worktreePath(forBranch: "detached", in: fixture.project)
    try FileManager.default.createDirectory(
      at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
    _ = try await fixture.runner.run(
      ["worktree", "add", "-q", "--detach", path.path], in: fixture.project.path)
    let worktree = try #require(
      try await fixture.coordinator.git.list(fixture.project).first {
        $0.isDetached && !$0.isPrimary
      })

    try await fixture.coordinator.removeUnlinking(
      worktree, deletingBranch: true, in: fixture.project)

    #expect(try await fixture.branches() == ["main"])
  }

  @Test func removalReportsEachStepAndSkipsWhatDoesNotApply() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let steps = Recorder<WorktreeRemovalStep>()
    try await fixture.coordinator.createThenRunPostCreate(
      branch: "plain", in: fixture.project, settings: fixture.worktreeSettings)
    let plain = try await fixture.worktree(onBranch: "plain")

    try await fixture.coordinator.removeUnlinking(
      plain, in: fixture.project, onStep: { steps.record($0) })
    #expect(steps.received == [.removingWorktree], "no hooks, branch kept")
    #expect(WorktreeRemovalStep.first(for: fixture.project) == .removingWorktree)

    var hooked = fixture.project
    hooked.settings = ProjectSettings(preDeleteHook: "true", postDeleteHook: "true")
    try await fixture.coordinator.createThenRunPostCreate(
      branch: "hooked", in: hooked, settings: fixture.worktreeSettings)
    let worktree = try await fixture.worktree(onBranch: "hooked", in: hooked)
    steps.clear()
    try await fixture.coordinator.removeUnlinking(
      worktree, deletingBranch: true, in: hooked, onStep: { steps.record($0) })
    #expect(
      steps.received == [.preDeleteHook, .removingWorktree, .postDeleteHook, .deletingBranch])
    #expect(WorktreeRemovalStep.first(for: hooked) == .preDeleteHook)
  }

  @Test func theDeleteHooksNeverRunAgainstADirectoryThatTookAStaleRecordsPath() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    var project = fixture.project
    let (stale, path) = try await fixture.worktreeWithItsDirectoryGone()
    try FileManager.default.createDirectory(at: path, withIntermediateDirectories: false)
    project.settings = ProjectSettings(
      preDeleteHook: "touch pre-ran \"$MULTISHELL_WORKTREE_PATH/pre-ran\"",
      postDeleteHook: "touch \"$MULTISHELL_WORKTREE_PATH/post-ran\"")

    try await fixture.coordinator.removeUnlinking(stale, in: project, shellPath: "/bin/sh")

    #expect(try FileManager.default.contentsOfDirectory(atPath: path.path).isEmpty)
    #expect(try await fixture.coordinator.git.list(project).map(\.branch) == ["main"])
  }

  @Test func aLockedWorktreeWhoseTrashRefusesStaysLocked() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = try await fixture.coordinator.createThenRunPostCreate(
      branch: "pinned", in: fixture.project, settings: fixture.worktreeSettings)
    _ = try await fixture.runner.run(
      ["worktree", "lock", "--reason", "external drive", path.path], in: fixture.project.path)
    let pinned = try await fixture.worktree(onBranch: "pinned")
    #expect(pinned.isLocked)

    await #expect(throws: TrashFailure.self) {
      try await fixture.coordinator.remove(
        pinned, in: fixture.project, trash: { _ in throw CocoaError(.fileWriteNoPermission) })
    }

    let after = try await fixture.worktree(onBranch: "pinned")
    #expect(after.isLocked, "the lock and its reason are the user's")
    let listed = try await fixture.runner.run(
      ["worktree", "list", "--porcelain"], in: fixture.project.path)
    #expect(listed.contains("locked external drive"))
  }

  /// `remove --force --force` on a directory still in place would unlink it,
  /// so a Trash that returned without taking it must stop the removal.
  @Test func aTrashThatTookNothingStopsBeforeGitIsAsked() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = try await fixture.coordinator.createThenRunPostCreate(
      branch: "untouched", in: fixture.project, settings: fixture.worktreeSettings)
    try "work\n".write(
      to: path.appendingPathComponent("wip.txt"), atomically: true, encoding: .utf8)
    let worktree = try await fixture.worktree(onBranch: "untouched")

    await #expect(throws: TrashFailure.self) {
      try await fixture.coordinator.remove(worktree, in: fixture.project, trash: { _ in })
    }

    #expect(FileManager.default.fileExists(atPath: path.appendingPathComponent("wip.txt").path))
    #expect(try await fixture.coordinator.git.list(fixture.project).count == 2, "still on record")
  }

  /// A trash standing in for the Finder's: the worktree moved into `bin` as
  /// `dirty`.
  private func moveToBin(_ bin: URL) -> @Sendable (URL) async throws -> Void {
    { url in
      try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
      try FileManager.default.moveItem(at: url, to: bin.appendingPathComponent("dirty"))
    }
  }
}
