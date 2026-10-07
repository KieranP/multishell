import Foundation
import MultishellCore
import Testing

@testable import MultishellGitKit

/// A watcher tick compares the records to decide whether to run `git worktree list`,
/// and `git status` writes the index into the same directory.
@Suite(.serialized)
struct WorktreeRecordsTests {
  @Test func indexWritesInALinkedWorktreeDoNotChangeTheRecords() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = try await fixture.coordinator.createThenRunPostCreateHook(
      branch: "work", in: fixture.project, settings: fixture.worktreeSettings)
    let common = try await fixture.coordinator.git.commonGitDirectory(fixture.project)
    let before = WorktreeRecords.read(in: common)
    #expect(before.files.keys.contains("worktrees/work/HEAD"))

    try "new\n".write(to: path.appendingPathComponent("n.txt"), atomically: true, encoding: .utf8)
    _ = try await fixture.runner.run(["add", "n.txt"], in: path)
    _ = try await fixture.runner.run(["status", "--porcelain"], in: path)

    #expect(WorktreeRecords.read(in: common) == before)
  }

  @Test func branchSwitchesLocksAndNewWorktreesChangeTheRecords() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let common = try await fixture.coordinator.git.commonGitDirectory(fixture.project)
    let empty = WorktreeRecords.read(in: common)

    let path = try await fixture.coordinator.createThenRunPostCreateHook(
      branch: "work", in: fixture.project, settings: fixture.worktreeSettings)
    let added = WorktreeRecords.read(in: common)
    #expect(added != empty)

    _ = try await fixture.runner.run(["checkout", "-q", "-b", "elsewhere"], in: path)
    let switched = WorktreeRecords.read(in: common)
    #expect(switched != added)

    _ = try await fixture.runner.run(["worktree", "lock", path.path], in: fixture.project.path)
    let locked = WorktreeRecords.read(in: common)
    #expect(locked != switched)

    _ = try await fixture.runner.run(
      ["checkout", "-q", "-b", "main-moved"], in: fixture.project.path)
    #expect(WorktreeRecords.read(in: common) != locked, "the main HEAD counts too")
  }

  @Test func watchPathsMoveFromDotGitToWorktreesOnceOneExists() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let project = fixture.project
    let coordinator = fixture.coordinator

    // Asked the way the app asks: the common directory once, then the
    // directories read off it without spawning git for each watcher tick.
    let common = try await coordinator.git.commonGitDirectory(project)

    let before = WorktreeRecords.directoriesToWatch(in: common)
    #expect(before.map(\.lastPathComponent) == [".git"])

    try await coordinator.createThenRunPostCreateHook(
      branch: "one", in: project, settings: fixture.worktreeSettings)
    let after = WorktreeRecords.directoriesToWatch(in: common)
    #expect(after.map(\.lastPathComponent) == ["worktrees", "one"])
  }
}
