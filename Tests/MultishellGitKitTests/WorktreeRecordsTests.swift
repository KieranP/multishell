import Foundation
import MultishellCore
import Testing

@testable import MultishellGitKit

/// The records are what a watcher tick compares to decide whether to run
/// `git worktree list`. They must move for anything that list would show and
/// stay put for the index writes `git status` makes in the same directory.
@Suite(.serialized)
struct WorktreeRecordsTests {
  @Test func indexWritesInALinkedWorktreeDoNotChangeTheRecords() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let path = try await repo.coordinator.create(
      branch: "work", in: repo.project, settings: repo.trees)
    let common = try await repo.coordinator.commonGitDirectory(repo.project)
    let before = WorktreeRecords.read(commonDirectory: common)
    #expect(before.files.keys.contains("worktrees/work/HEAD"))

    try "new\n".write(to: path.appendingPathComponent("n.txt"), atomically: true, encoding: .utf8)
    _ = try await repo.git.run(["add", "n.txt"], in: path)
    _ = try await repo.git.run(["status", "--porcelain"], in: path)

    #expect(WorktreeRecords.read(commonDirectory: common) == before)
  }

  @Test func branchSwitchesLocksAndNewWorktreesChangeTheRecords() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let common = try await repo.coordinator.commonGitDirectory(repo.project)
    let empty = WorktreeRecords.read(commonDirectory: common)

    let path = try await repo.coordinator.create(
      branch: "work", in: repo.project, settings: repo.trees)
    let added = WorktreeRecords.read(commonDirectory: common)
    #expect(added != empty)

    _ = try await repo.git.run(["checkout", "-q", "-b", "elsewhere"], in: path)
    let switched = WorktreeRecords.read(commonDirectory: common)
    #expect(switched != added)

    _ = try await repo.git.run(["worktree", "lock", path.path], in: repo.project.path)
    let locked = WorktreeRecords.read(commonDirectory: common)
    #expect(locked != switched)

    _ = try await repo.git.run(["checkout", "-q", "-b", "main-moved"], in: repo.project.path)
    #expect(WorktreeRecords.read(commonDirectory: common) != locked, "the main HEAD counts too")
  }
}

@Suite(.serialized)
struct RepositoryRootTests {
  @Test func aSubdirectoryAndALinkedWorktreeResolveToTheMainWorktree() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let linked = try await repo.coordinator.create(
      branch: "side", in: repo.project, settings: repo.trees)
    let subdirectory = repo.project.path.appendingPathComponent("Sources", isDirectory: true)
    try FileManager.default.createDirectory(at: subdirectory, withIntermediateDirectories: true)

    func root(_ url: URL) async throws -> String {
      try await repo.coordinator.repositoryRoot(containing: url).resolvingSymlinksInPath().path
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
      try await repo.coordinator.repositoryRoot(containing: repo.root)
    }
  }
}
