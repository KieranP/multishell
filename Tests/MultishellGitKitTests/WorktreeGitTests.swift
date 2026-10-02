import Foundation
import MultishellCore
import TestScratch
import Testing

@testable import MultishellGitKit

@Suite(.serialized)
struct WorktreeGitTests {
  @Test func aRepositoryIsRecognisedAndItsParentAndAnEmptyDirectoryAreNot() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let empty = try Scratch.directory("empty")
    defer { Scratch.remove(empty) }

    #expect(await fixture.coordinator.git.isRepository(fixture.project.path))
    #expect(await fixture.coordinator.git.isRepository(fixture.root) == false)
    #expect(await WorktreeGit(runner: try GitRunner()).isRepository(empty) == false)
  }

  @Test func aFreshRepositoryHasNoCommitsUntilTheFirstIsMade() async throws {
    let fixture = try await RepositoryFixture.make(commit: false)
    defer { fixture.tearDown() }
    let project = fixture.project
    let coordinator = fixture.coordinator

    #expect(await coordinator.git.hasCommits(project) == false)
    try await fixture.commit("first", file: "f", content: "x\n")
    #expect(await coordinator.git.hasCommits(project) == true)
  }
}
