import Foundation
import TestScratch
import TestSupport
import Testing

@testable import MultishellCore
@testable import MultishellGitKit

extension WorktreeCoordinatorRemovalTests {
  @Test func aWorktreeHoldingAnotherWorktreeIsRefusedAndBothStay() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let outer = try await fixture.coordinator.createThenRunPostCreateHook(
      branch: "outer",
      in: fixture.project,
      settings: fixture.worktreeSettings,
    )
    let inner = outer.appendingPathComponent(".worktrees/inner", isDirectory: true)
    _ = try await fixture.runner.run(
      ["worktree", "add", "-q", "-b", "inner", inner.path],
      in: outer,
    )
    try "work\n".write(
      to: inner.appendingPathComponent("wip.txt"),
      atomically: true,
      encoding: .utf8,
    )
    let worktree = try await fixture.worktree(onBranch: "outer")

    await #expect(throws: WorktreeHoldsOtherWork.self) {
      try await fixture.coordinator.removeUnlinking(worktree, in: fixture.project)
    }

    #expect(FileManager.default.fileExists(atPath: inner.appendingPathComponent("wip.txt").path))
    #expect(try await fixture.git.list(fixture.project).count == 3)
  }

  @Test func aWorktreeWhoseSubmoduleIsInitialisedIsRefusedAndKeepsItsRepository() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let upstream = fixture.root.appendingPathComponent("upstream", isDirectory: true)
    try await TestRepository.initialise(at: upstream, withFirstCommit: true)
    let allowingFile = ["-c", "protocol.file.allow=always"]
    _ = try await fixture.runner.run(
      allowingFile + ["submodule", "add", "-q", upstream.path, "sub"],
      in: fixture.project.path,
    )
    _ = try await fixture.runner.run(["commit", "-q", "-m", "add sub"], in: fixture.project.path)
    let path = try await fixture.coordinator.createThenRunPostCreateHook(
      branch: "feature",
      in: fixture.project,
      settings: fixture.worktreeSettings,
    )
    _ = try await fixture.runner.run(
      allowingFile + ["submodule", "update", "--init", "-q"],
      in: path,
    )
    let worktree = try await fixture.worktree(onBranch: "feature")

    await #expect(throws: WorktreeHoldsOtherWork.self) {
      try await fixture.coordinator.removeUnlinking(worktree, in: fixture.project)
    }

    #expect(FileManager.default.fileExists(atPath: path.appendingPathComponent("sub/.git").path))
    #expect(try await fixture.git.list(fixture.project).count == 2)
  }

  @Test func aWorktreeWhoseSubmodulesWereDeinitialisedIsRemovedAsGitWould() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let upstream = fixture.root.appendingPathComponent("upstream", isDirectory: true)
    try await TestRepository.initialise(at: upstream, withFirstCommit: true)
    let allowingFile = ["-c", "protocol.file.allow=always"]
    _ = try await fixture.runner.run(
      allowingFile + ["submodule", "add", "-q", upstream.path, "sub"],
      in: fixture.project.path,
    )
    _ = try await fixture.runner.run(["commit", "-q", "-m", "add sub"], in: fixture.project.path)
    let path = try await fixture.coordinator.createThenRunPostCreateHook(
      branch: "feature",
      in: fixture.project,
      settings: fixture.worktreeSettings,
    )
    _ = try await fixture.runner.run(
      allowingFile + ["submodule", "update", "--init", "-q"],
      in: path,
    )
    _ = try await fixture.runner.run(["submodule", "deinit", "-q", "--all"], in: path)
    let worktree = try await fixture.worktree(onBranch: "feature")

    try await fixture.coordinator.removeUnlinking(worktree, in: fixture.project)

    #expect(try await fixture.git.list(fixture.project).count == 1)
  }
}
