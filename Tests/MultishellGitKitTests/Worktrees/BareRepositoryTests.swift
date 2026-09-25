import Foundation
import MultishellCore
import Testing

@testable import MultishellGitKit

/// A bare clone with its worktrees beside it, against real git.
@Suite(.serialized)
struct BareRepositoryTests {
  @Test func aBareRepositoryIsARepositoryAndIsTheProjectsRoot() async throws {
    let (repo, checkout) = try await RepositoryFixture.makeBare()
    defer { repo.tearDown() }

    #expect(await repo.coordinator.git.isRepository(repo.project.path))
    #expect(await repo.coordinator.git.isRepository(checkout))
    #expect(await repo.coordinator.git.isRepository(repo.root) == false)
    #expect(try await repo.coordinator.git.mainWorktree(containing: checkout) == repo.project.path)
    #expect(repo.project.name == "repo")
  }

  @Test func theListLeadsWithTheBareEntryWhichGetsNoStatus() async throws {
    let (repo, _) = try await RepositoryFixture.makeBare()
    defer { repo.tearDown() }

    let listed = try await repo.coordinator.git.list(repo.project)
    #expect(listed.map(\.isBare) == [true, false])
    #expect(listed[0].isPrimary && listed[0].name == "repo.git")
    #expect(listed[1].branch == "main")

    let statuses = await repo.coordinator.readStatuses(of: listed).mapValues(\.status)
    #expect(statuses.keys.sorted() == [listed[1].id], "git status has no work tree to read there")
  }

  @Test func worktreesAreCreatedAndRemovedFromTheBareRepository() async throws {
    let (repo, _) = try await RepositoryFixture.makeBare()
    defer { repo.tearDown() }
    #expect(await repo.coordinator.git.hasCommits(repo.project))
    #expect(try await repo.coordinator.git.currentBranch(repo.project) == "main")

    let path = try await repo.coordinator.create(
      branch: "feat", in: repo.project, settings: repo.trees)
    #expect(path.path.hasSuffix("/trees/feat"))
    let created = try #require(
      try await repo.coordinator.git.list(repo.project).first { $0.branch == "feat" })
    try await repo.coordinator.remove(created, deletingBranch: true, in: repo.project)
    #expect(try await repo.coordinator.git.list(repo.project).count == 2)
    #expect(try await repo.branches() == ["main"])
  }

  @Test func theCommonDirectoryIsTheBareRepositoryItself() async throws {
    let (repo, _) = try await RepositoryFixture.makeBare()
    defer { repo.tearDown() }
    let common = try await repo.coordinator.git.commonGitDirectory(repo.project)
    #expect(common.standardizedFileURL.path == repo.project.path.path)
    #expect(
      WorktreeRecords.directoriesToWatch(in: common).map(\.lastPathComponent).sorted()
        == ["main", "worktrees"])
  }
}
