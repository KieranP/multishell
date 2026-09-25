import Foundation
import MultishellCore
import Testing

@testable import MultishellGitKit

/// A watcher tick compares the records to decide whether to run `git worktree list`,
/// and `git status` writes the index into the same directory.
@Suite(.serialized)
struct WorktreeRecordsTests {
  @Test func indexWritesInALinkedWorktreeDoNotChangeTheRecords() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let path = try await repo.coordinator.create(
      branch: "work", in: repo.project, settings: repo.trees)
    let common = try await repo.coordinator.git.commonGitDirectory(repo.project)
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
    let common = try await repo.coordinator.git.commonGitDirectory(repo.project)
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
