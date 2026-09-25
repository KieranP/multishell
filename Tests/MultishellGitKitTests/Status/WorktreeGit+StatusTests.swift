import Foundation
import MultishellCore
import Testing

@testable import MultishellGitKit

@Suite(.serialized)
struct WorktreeGitStatusTests {
  /// A stale index makes a plain `git status` rewrite it under `index.lock`, which trips a
  /// commit typed at that moment; see Docs/design/worktrees.md.
  @Test func aStatusPollNeverWritesTheIndex() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let index = repo.project.path.appendingPathComponent(".git/index")
    func indexModified() throws -> Date {
      try #require(
        FileManager.default.attributesOfItem(atPath: index.path)[.modificationDate] as? Date)
    }
    let before = try indexModified()
    try await Task.sleep(for: .milliseconds(50))
    try "changed\n".write(
      to: repo.project.path.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
    let main = try await repo.coordinator.git.list(repo.project)[0]

    let status = try await WorktreeGit(runner: repo.git).status(of: main)

    #expect(status.unstaged == 1, "the change was seen")
    #expect(try indexModified() == before, "the index was rewritten")
    #expect(
      !FileManager.default.fileExists(
        atPath: repo.project.path.appendingPathComponent(".git/index.lock").path))
  }
}
