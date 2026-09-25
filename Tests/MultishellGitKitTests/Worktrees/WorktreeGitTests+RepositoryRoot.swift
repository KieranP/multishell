import Foundation
import MultishellCore
import Testing

@testable import MultishellGitKit

extension WorktreeGitTests {
  @Test func aSubdirectoryAndALinkedWorktreeResolveToTheMainWorktree() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let linked = try await repo.coordinator.create(
      branch: "side", in: repo.project, settings: repo.trees)
    let subdirectory = repo.project.path.appendingPathComponent("Sources", isDirectory: true)
    try FileManager.default.createDirectory(at: subdirectory, withIntermediateDirectories: true)

    func root(_ url: URL) async throws -> String {
      try await repo.coordinator.git.mainWorktree(containing: url).resolvingSymlinksInPath().path
    }
    let main = repo.project.path.resolvingSymlinksInPath().path

    #expect(try await root(repo.project.path) == main)
    #expect(try await root(subdirectory) == main)
    #expect(try await root(linked) == main, "a linked worktree is the same project")
  }

  @Test func aDirectoryOutsideAnyRepositoryIsAnError() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    await #expect(throws: (any Error).self) {
      try await repo.coordinator.git.mainWorktree(containing: repo.root)
    }
  }
}
