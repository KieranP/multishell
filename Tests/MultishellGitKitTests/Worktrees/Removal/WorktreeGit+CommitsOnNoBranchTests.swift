import Foundation
import TestSupport
import Testing

@testable import MultishellCore
@testable import MultishellGitKit

@Suite(.serialized)
struct WorktreeGitCommitsOnNoBranchTests {
  @Test func aDetachedWorktreesOwnCommitsAreCountedAndABranchsAreNot() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let tree = try await fixture.addWorktree(onNewBranch: "pinned")
    let onBranch = try await fixture.worktree(onBranch: "pinned")
    #expect(await fixture.git.commitsOnNoBranch(in: onBranch) == 0)

    _ = try await fixture.runner.run(["checkout", "--detach"], in: tree)
    try await TestRepository.commit(
      "one",
      files: ["one.txt": "1"],
      in: tree,
      using: fixture.runner,
    )
    try await TestRepository.commit(
      "two",
      files: ["two.txt": "2"],
      in: tree,
      using: fixture.runner,
    )
    let detached = try #require(
      try await fixture.git.list(fixture.project).first { $0.path == onBranch.path }
    )

    #expect(await fixture.git.commitsOnNoBranch(in: detached) == 2)
  }
}
