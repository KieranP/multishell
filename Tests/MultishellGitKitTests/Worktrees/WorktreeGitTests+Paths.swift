import Foundation
import MultishellCore
import Testing

@testable import MultishellGitKit

extension WorktreeGitTests {
  /// git's own docs call the non-`-z` porcelain unsafe for paths with
  /// newlines: the second half reads as another attribute line.
  @Test func aWorktreePathHoldingANewlineIsStillOneWorktree() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let odd = fixture.root.appendingPathComponent("my\nrepo", isDirectory: true)
    _ = try await fixture.git.run(
      ["worktree", "add", "-q", "-b", "odd", odd.path], in: fixture.project.path)

    let worktrees = try await WorktreeGit(runner: fixture.git).list(fixture.project)

    #expect(worktrees.count == 2, "got \(worktrees.map(\.path.path))")
    let listed = worktrees.first { !$0.isPrimary }
    #expect(listed?.path.lastPathComponent == "my\nrepo")
    #expect(listed?.branch == "odd")
  }
}
