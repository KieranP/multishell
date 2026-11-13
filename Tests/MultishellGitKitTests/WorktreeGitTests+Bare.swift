import Foundation
import MultishellCore
import TestSupport
import Testing

@testable import MultishellGitKit

extension WorktreeGitTests {
  @Test func aBareRepositoryIsARepositoryAndIsTheProjectsRoot() async throws {
    let (fixture, checkout) = try await RepositoryFixture.makeBare()
    defer { fixture.tearDown() }

    #expect(await fixture.git.isRepository(fixture.project.path))
    #expect(await fixture.git.isRepository(checkout))
    #expect(await fixture.git.isRepository(fixture.root) == false)
    #expect(
      try await fixture.git.mainWorktreePath(containing: checkout)
        == fixture.project.path
    )
    #expect(fixture.project.name == "repo")
  }

  @Test func theListLeadsWithTheBareEntryWhichGetsNoStatus() async throws {
    let (fixture, _) = try await RepositoryFixture.makeBare()
    defer { fixture.tearDown() }

    let listed = try await fixture.git.list(fixture.project)
    #expect(listed.map(\.isBare) == [true, false])
    #expect(listed[0].isPrimary && listed[0].name == "repo.git")
    #expect(listed[1].branch == "main")

    let statuses = await fixture.coordinator.readStatuses(of: listed).mapValues(\.status)
    #expect(statuses.keys.sorted() == [listed[1].id], "git status has no work tree to read there")
  }

  @Test func worktreesAreCreatedAndRemovedFromTheBareRepository() async throws {
    let (fixture, _) = try await RepositoryFixture.makeBare()
    defer { fixture.tearDown() }
    #expect(await fixture.git.hasCommits(fixture.project))
    #expect(try await fixture.git.currentBranch(fixture.project) == "main")

    let path = try await fixture.coordinator.createThenRunPostCreateHook(
      branch: "feat",
      in: fixture.project,
      settings: fixture.worktreeSettings,
    )
    #expect(path.path.hasSuffix("/trees/feat"))
    let created = try await fixture.worktree(onBranch: "feat")
    try await fixture.coordinator.removeUnlinking(
      created,
      in: fixture.project,
      deletesBranch: true,
    )
    #expect(try await fixture.git.list(fixture.project).count == 2)
    #expect(try await fixture.branches() == ["main"])
  }

  @Test func removingTheTrunksWorktreeKeepsTheBranchTheBareRepositoryNames() async throws {
    let (fixture, checkout) = try await RepositoryFixture.makeBare()
    defer { fixture.tearDown() }
    try await TestRepository.commit(
      "unpushed",
      files: ["local.txt": "work"],
      in: checkout,
      using: fixture.runner,
    )
    let trunk = try await fixture.worktree(onBranch: "main")

    try? await fixture.coordinator.removeUnlinking(trunk, in: fixture.project, deletesBranch: true)

    #expect(try await fixture.branches() == ["main"])
  }

  @Test func theCommonDirectoryIsTheBareRepositoryItself() async throws {
    let (fixture, _) = try await RepositoryFixture.makeBare()
    defer { fixture.tearDown() }
    let common = try await fixture.git.commonGitDirectory(fixture.project)
    #expect(common.standardizedFileURL.path == fixture.project.path.path)
  }
}
