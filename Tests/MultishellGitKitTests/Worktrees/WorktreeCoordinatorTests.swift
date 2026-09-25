import Foundation
import Testing

@testable import MultishellCore
@testable import MultishellGitKit

/// End-to-end against a real repository in a temporary directory.
@Suite(.serialized)
struct WorktreeCoordinatorTests {
  @Test func createsAWorktreeWhereTheSettingsSayAndRunsTheHook() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }

    var project = repo.project
    project.settings = ProjectSettings(postCreateHook: "echo created > hook.txt")
    let settings = WorktreeSettings(worktreeDirectory: "../trees", branchPrefix: "kieran/")

    let coordinator = repo.coordinator
    let path = try await coordinator.create(branch: "tabs", in: project, settings: settings)

    #expect(path.lastPathComponent == "kieran-tabs")
    #expect(path.deletingLastPathComponent().lastPathComponent == "trees")
    #expect(FileManager.default.fileExists(atPath: path.appendingPathComponent("hook.txt").path))

    let worktrees = try await coordinator.git.list(project)
    #expect(worktrees.count == 2)
    #expect(worktrees.contains { $0.branch == "kieran/tabs" })
  }

  @Test func creationReportsEachStepAndSkipsHooksWithNoScript() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let steps = StepLog<WorktreeCreationStep>()

    try await repo.coordinator.create(
      branch: "plain", in: repo.project, settings: repo.worktreeSettings, onStep: { steps.add($0) })
    #expect(steps.steps == [.addingWorktree], "no hooks, so no hook steps")

    var hooked = repo.project
    hooked.settings = ProjectSettings(preCreateHook: "true", postCreateHook: "true")
    steps.clear()
    try await repo.coordinator.create(
      branch: "hooked", in: hooked, settings: repo.worktreeSettings, onStep: { steps.add($0) })
    #expect(steps.steps == [.preCreateHook, .addingWorktree])

    var refused = repo.project
    refused.settings = ProjectSettings(preCreateHook: "exit 1", postCreateHook: "true")
    steps.clear()
    await #expect(throws: HookFailure.self) {
      try await repo.coordinator.create(
        branch: "refused", in: refused, settings: repo.worktreeSettings, onStep: { steps.add($0) })
    }
    #expect(steps.steps == [.preCreateHook], "nothing past the veto")
  }

  @Test func addStopsBeforeThePostHookWhichRunPostCreateThenRuns() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    var project = repo.project
    project.settings = ProjectSettings(
      preCreateHook: "echo pre > pre.txt", postCreateHook: "echo post > post.txt")

    let path = try await repo.coordinator.add(
      branch: "halves", in: project, settings: repo.worktreeSettings)

    #expect(
      FileManager.default.fileExists(atPath: project.path.appendingPathComponent("pre.txt").path))
    #expect(try await repo.coordinator.git.list(project).count == 2, "the worktree exists")
    #expect(!FileManager.default.fileExists(atPath: path.appendingPathComponent("post.txt").path))

    try await repo.coordinator.runPostCreate(for: project, worktreePath: path, branch: "halves")
    #expect(FileManager.default.fileExists(atPath: path.appendingPathComponent("post.txt").path))
  }

  @Test func theListReflectsCreateAndRemove() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }

    try await repo.coordinator.create(
      branch: "a", in: repo.project, settings: repo.worktreeSettings)
    try await repo.coordinator.create(
      branch: "b", in: repo.project, settings: repo.worktreeSettings)
    var listed = try await repo.coordinator.git.list(repo.project)
    #expect(listed.map(\.branch) == ["main", "a", "b"])
    #expect(listed[0].isPrimary && !listed[1].isPrimary)
    #expect(listed.allSatisfy { $0.projectID == repo.project.id })

    try await repo.coordinator.remove(listed[1], in: repo.project)
    listed = try await repo.coordinator.git.list(repo.project)
    #expect(listed.map(\.branch) == ["main", "b"])
  }
}
