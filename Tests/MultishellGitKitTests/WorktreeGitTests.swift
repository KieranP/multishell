import Foundation
import MultishellCore
import TestScratch
import Testing

@testable import MultishellGitKit

@Suite(.serialized)
struct WorktreeGitTests {
  @Test func aRepositoryIsRecognisedAndItsParentAndAnEmptyDirectoryAreNot() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let empty = try Scratch.directory("empty")
    defer { Scratch.remove(empty) }

    #expect(await repo.coordinator.git.isRepository(repo.project.path))
    #expect(await repo.coordinator.git.isRepository(repo.root) == false)
    #expect(await WorktreeGit(runner: try GitRunner()).isRepository(empty) == false)
  }

  @Test func aFreshRepositoryHasNoCommitsUntilTheFirstIsMade() async throws {
    let repo = try await RepositoryFixture.make(commit: false)
    defer { repo.tearDown() }
    let project = repo.project
    let coordinator = repo.coordinator

    #expect(await coordinator.git.hasCommits(project) == false)
    try "x\n".write(to: project.path.appendingPathComponent("f"), atomically: true, encoding: .utf8)
    _ = try await repo.runner.run(["add", "."], in: project.path)
    _ = try await repo.runner.run(["commit", "-m", "first"], in: project.path)
    #expect(await coordinator.git.hasCommits(project) == true)
  }
}
