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

    #expect(await fixture.git.isRepository(fixture.project.path))
    #expect(await fixture.git.isRepository(fixture.root) == false)
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

  @Test func pathsGitPrintsAreSplitOnlyWhereGitEndsALine() {
    let directory = URL(fileURLWithPath: "/repos/x")

    let paths = WorktreeGit.absolutePaths(in: "/repos/a\u{2028}b\n/repos/c\n", from: directory)

    #expect(paths.map(\.path) == ["/repos/a\u{2028}b", "/repos/c"])
  }

  @Test func aNestedRepositoryWhoseNameEndsInASpaceIsItsOwnTop() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let nested = fixture.project.path.appendingPathComponent("lib ")
    try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
    _ = try await fixture.runner.run(["init", "-q"], in: nested)

    #expect(await fixture.git.isRepositoryTop(nested))
  }
}
