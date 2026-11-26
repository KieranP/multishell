import Foundation
import TestSupport
import Testing

@testable import MultishellCore
@testable import MultishellGitKit

extension WorktreeCoordinatorRemovalTests {
  @Test func removingFromAProjectWhoseGitWentMissingLeavesTheEnclosingRepositorysBranch()
    async throws
  {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    _ = try await fixture.runner.run(["branch", "side"], in: fixture.project.path)
    let inner = Project(
      path: fixture.project.path.appendingPathComponent("inner", isDirectory: true)
    )
    try await TestRepository.initialise(at: inner.path, withFirstCommit: true)
    let linked = fixture.root.appendingPathComponent("inner-side", isDirectory: true)
    try await TestRepository.addWorktree(
      onNewBranch: "side",
      at: linked,
      in: inner.path,
      using: fixture.runner,
    )
    let worktree = try await fixture.worktree(onBranch: "side", in: inner)
    try FileManager.default.removeItem(at: linked)
    try FileManager.default.removeItem(at: inner.path.appendingPathComponent(".git"))

    try? await fixture.coordinator.removeUnlinking(worktree, in: inner, deletesBranch: true)

    #expect(try await fixture.branches().contains("side"))
  }

  @Test func removingFromAProjectWhoseGitWentMissingKeepsTheEnclosingRepositorysStaleRecords()
    async throws
  {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let outerStale = fixture.root.appendingPathComponent("outer-stale", isDirectory: true)
    try await TestRepository.addWorktree(
      onNewBranch: "outer-stale",
      at: outerStale,
      in: fixture.project.path,
      using: fixture.runner,
    )
    try FileManager.default.removeItem(at: outerStale)
    let inner = Project(
      path: fixture.project.path.appendingPathComponent("inner", isDirectory: true)
    )
    try await TestRepository.initialise(at: inner.path, withFirstCommit: true)
    let linked = fixture.root.appendingPathComponent("inner-side", isDirectory: true)
    try await TestRepository.addWorktree(
      onNewBranch: "side",
      at: linked,
      in: inner.path,
      using: fixture.runner,
    )
    let worktree = try await fixture.worktree(onBranch: "side", in: inner)
    try FileManager.default.removeItem(at: linked)
    try FileManager.default.removeItem(at: inner.path.appendingPathComponent(".git"))

    try? await fixture.coordinator.removeUnlinking(worktree, in: inner)

    let records = fixture.project.path.appendingPathComponent(".git/worktrees/outer-stale")
    #expect(FileManager.default.fileExists(atPath: records.path))
  }
}
