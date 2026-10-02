import Foundation
import MultishellCore
import MultishellProcess
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

extension AppModelWorktreeRemovalTests {
  @Test func aTrashThatRefusesFallsBackToDeletingTheDirectory() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    await harness.model.createWorktree(
      branch: "stuck", basedOn: nil, createsBranch: true, in: harness.project)
    let worktree = try #require(harness.worktree(onBranch: "stuck"))
    harness.platform.trash = nil

    await harness.model.removeWorktree(worktree)

    #expect(harness.model.presentedError == nil)
    #expect(harness.worktree(onBranch: "stuck") == nil)
    #expect(!FileManager.default.fileExists(atPath: worktree.path.path), "deleted outright")
    #expect(harness.platform.logged.count == 1, "the fallback leaves a line in the log")
  }

  /// The model is on the main actor and a Trash on a network share walks the
  /// whole tree, so the walk must not be where the window's events are.
  @Test func theTrashIsAskedOffTheMainThread() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    await harness.model.createWorktree(
      branch: "heavy", basedOn: nil, createsBranch: true, in: harness.project)
    let worktree = try #require(harness.worktree(onBranch: "heavy"))
    harness.platform.trash = nil

    await harness.model.removeWorktree(worktree)

    #expect(
      harness.platform.trashCallsOnMainThread == [false], "the Trash was asked off the main thread")
    #expect(!FileManager.default.fileExists(atPath: worktree.path.path))
  }

  @Test func aDirectoryThatCanBeNeitherTrashedNorDeletedKeepsTheWorktree() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    await harness.model.createWorktree(
      branch: "pinned", basedOn: nil, createsBranch: true, in: harness.project)
    let worktree = try #require(harness.worktree(onBranch: "pinned"))
    harness.platform.trash = nil
    // A read-only parent refuses the unlink of its entries.
    let container = worktree.path.deletingLastPathComponent()
    try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: container.path)
    defer {
      try? FileManager.default.setAttributes(
        [.posixPermissions: 0o755], ofItemAtPath: container.path)
    }

    await harness.model.removeWorktree(worktree)

    let alert = try #require(harness.model.presentedError)
    #expect(alert.title.hasPrefix("Worktree not removed: the directory could not be moved"))
    #expect(alert.retry == nil)
    #expect(harness.worktree(onBranch: "pinned") != nil && harness.model.worktreeOperations.isEmpty)
    #expect(FileManager.default.fileExists(atPath: worktree.path.path))
    #expect(harness.model.liveTerminalCount == 1, "the shell is still there")
  }
}
