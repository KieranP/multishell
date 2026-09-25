import Foundation
import MultishellCore
import MultishellProcess
import TestScratch
import Testing

@testable import MultishellGitKit

@Suite(.serialized)
struct WorktreeCoordinatorRemovalTests {
  @Test func removingKeepsTheBranch() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    try await repo.coordinator.create(
      branch: "keep", in: repo.project, settings: repo.worktreeSettings)
    let worktree = try await repo.worktree(onBranch: "keep")

    try await repo.coordinator.remove(worktree, in: repo.project)

    #expect(try await repo.branches() == ["keep", "main"])
    #expect(!FileManager.default.fileExists(atPath: worktree.path.path))
  }

  @Test func aDirtyWorktreeIsHandedToTheTrashNotRefused() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let path = try await repo.coordinator.create(
      branch: "dirty", in: repo.project, settings: repo.worktreeSettings)
    try "uncommitted\n".write(
      to: path.appendingPathComponent("work.txt"), atomically: true, encoding: .utf8)
    let worktree = try await repo.worktree(onBranch: "dirty")
    let bin = repo.root.appendingPathComponent("bin", isDirectory: true)

    try await repo.coordinator.remove(
      worktree, in: repo.project,
      trash: { url in
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: url, to: bin.appendingPathComponent("dirty"))
      })

    #expect(!FileManager.default.fileExists(atPath: path.path))
    #expect(
      FileManager.default.fileExists(atPath: bin.appendingPathComponent("dirty/work.txt").path))
    #expect(try await repo.coordinator.git.list(repo.project).count == 1)
  }

  @Test func aTrashedWorktreeIsHandedOverThenForgottenAndTheHooksStillRun() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    var project = repo.project
    project.settings = ProjectSettings(postDeleteHook: "echo gone > deleted.txt")
    let path = try await repo.coordinator.create(
      branch: "dirty", in: project, settings: repo.worktreeSettings)
    try "work\n".write(
      to: path.appendingPathComponent("wip.txt"), atomically: true, encoding: .utf8)
    let worktree = try await repo.worktree(onBranch: "dirty", in: project)
    let bin = repo.root.appendingPathComponent("bin", isDirectory: true)
    let steps = StepLog<WorktreeRemovalStep>()

    try await repo.coordinator.remove(
      worktree, in: project,
      trash: { url in
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: url, to: bin.appendingPathComponent("dirty"))
      },
      onStep: { steps.add($0) })

    #expect(steps.steps == [.removingWorktree, .postDeleteHook])
    #expect(try await repo.coordinator.git.list(project).count == 1, "forgotten")
    #expect(
      FileManager.default.fileExists(atPath: bin.appendingPathComponent("dirty/wip.txt").path),
      "the work is where the Trash put it")
    #expect(
      FileManager.default.fileExists(
        atPath: project.path.appendingPathComponent("deleted.txt").path))
    #expect(WorktreeRemovalStep.first(for: project) == .removingWorktree)
  }

  @Test func aTrashThatRefusesLeavesTheWorktreeRegisteredAndInPlace() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let path = try await repo.coordinator.create(
      branch: "kept", in: repo.project, settings: repo.worktreeSettings)
    let worktree = try await repo.worktree(onBranch: "kept")

    await #expect(throws: TrashFailure.self) {
      try await repo.coordinator.remove(
        worktree, in: repo.project, trash: { _ in throw CocoaError(.fileWriteNoPermission) })
    }
    #expect(FileManager.default.fileExists(atPath: path.path))
    #expect(try await repo.coordinator.git.list(repo.project).count == 2, "nothing was pruned")
  }

  @Test func removesAWorktreeAndRunsTheDeleteHook() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }

    var project = repo.project
    project.settings = ProjectSettings(postDeleteHook: "echo gone > deleted.txt")
    let settings = repo.worktreeSettings

    let coordinator = repo.coordinator
    try await coordinator.create(branch: "scratch", in: project, settings: settings)

    let worktree = try await repo.worktree(onBranch: "scratch", in: project)
    try await coordinator.remove(worktree, in: project)

    #expect(try await coordinator.git.list(project).count == 1)
    #expect(
      FileManager.default.fileExists(
        atPath: project.path.appendingPathComponent("deleted.txt").path))
  }

  @Test func removingCanDeleteTheBranchAfterThePostHookHasSeenIt() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    var project = repo.project
    project.settings = ProjectSettings(
      postDeleteHook: "git rev-parse --verify \"$MULTISHELL_BRANCH\" > hook-saw-branch.txt")
    try await repo.coordinator.create(branch: "done", in: project, settings: repo.worktreeSettings)
    let worktree = try await repo.worktree(onBranch: "done", in: project)

    try await repo.coordinator.remove(worktree, deletingBranch: true, in: project)

    #expect(try await repo.branches() == ["main"])
    let seen = try String(
      contentsOf: project.path.appendingPathComponent("hook-saw-branch.txt"), encoding: .utf8)
    #expect(!seen.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "the hook ran first")
  }

  @Test func aBranchWithItsOwnCommitsIsRefusedThenForced() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let path = try await repo.coordinator.create(
      branch: "unmerged", in: repo.project, settings: repo.worktreeSettings)
    try "work\n".write(to: path.appendingPathComponent("w.txt"), atomically: true, encoding: .utf8)
    _ = try await repo.git.run(["add", "."], in: path)
    _ = try await repo.git.run(["commit", "-q", "-m", "unmerged"], in: path)
    let worktree = try await repo.worktree(onBranch: "unmerged")

    await #expect(throws: BranchDeletionFailure.self) {
      try await repo.coordinator.remove(worktree, deletingBranch: true, in: repo.project)
    }

    #expect(
      try await repo.coordinator.git.list(repo.project).count == 1, "the worktree is gone")
    #expect(try await repo.branches() == ["main", "unmerged"], "the branch is kept")

    try await repo.coordinator.deleteBranch("unmerged", force: true, in: repo.project)
    #expect(try await repo.branches() == ["main"])
  }

  @Test func aDetachedWorktreeHasNoBranchToDelete() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let path = repo.worktreeSettings.worktreePath(forBranch: "detached", in: repo.project)
    try FileManager.default.createDirectory(
      at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
    _ = try await repo.git.run(
      ["worktree", "add", "-q", "--detach", path.path], in: repo.project.path)
    let worktree = try #require(
      try await repo.coordinator.git.list(repo.project).first {
        $0.isDetached && !$0.isPrimary
      })

    try await repo.coordinator.remove(worktree, deletingBranch: true, in: repo.project)

    #expect(try await repo.branches() == ["main"])
  }

  @Test func removalReportsEachStepAndSkipsWhatDoesNotApply() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let steps = StepLog<WorktreeRemovalStep>()
    try await repo.coordinator.create(
      branch: "plain", in: repo.project, settings: repo.worktreeSettings)
    let plain = try await repo.worktree(onBranch: "plain")

    try await repo.coordinator.remove(plain, in: repo.project, onStep: { steps.add($0) })
    #expect(steps.steps == [.removingWorktree], "no hooks, branch kept")
    #expect(WorktreeRemovalStep.first(for: repo.project) == .removingWorktree)

    var hooked = repo.project
    hooked.settings = ProjectSettings(preDeleteHook: "true", postDeleteHook: "true")
    try await repo.coordinator.create(branch: "hooked", in: hooked, settings: repo.worktreeSettings)
    let worktree = try await repo.worktree(onBranch: "hooked", in: hooked)
    steps.clear()
    try await repo.coordinator.remove(
      worktree, deletingBranch: true, in: hooked, onStep: { steps.add($0) })
    #expect(
      steps.steps == [.preDeleteHook, .removingWorktree, .postDeleteHook, .deletingBranch])
    #expect(WorktreeRemovalStep.first(for: hooked) == .preDeleteHook)
  }
}
