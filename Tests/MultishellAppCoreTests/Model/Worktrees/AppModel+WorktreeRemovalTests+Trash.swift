import Foundation
import MultishellCore
import MultishellProcess
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

extension AppModelWorktreeRemovalTests {
  /// The main worktree is the repository. Only a sidebar condition three
  /// modules away kept it off this call, and the trash step would bin `.git`.
  @Test func removingTheMainWorktreeIsRefusedBeforeAnythingRuns() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let marker = h.root.appendingPathComponent("delete-hook-ran")
    h.model.updateSettings(
      ProjectSettings(preDeleteHook: "touch \(marker.path)"), for: h.project)
    let main = try #require(h.worktree(onBranch: "main"))
    #expect(main.isPrimary)

    await h.model.removeWorktree(main)

    #expect(!FileManager.default.fileExists(atPath: marker.path), "the hook did not run")
    #expect(h.platform.trashed.isEmpty, "and nothing went to the Trash")
    #expect(FileManager.default.fileExists(atPath: main.path.path))
    #expect(h.model.presentedError != nil)
  }

  @Test func aLockedWorktreeIsForgottenLockAndAll() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "locked", basedOn: nil, createBranch: true, in: h.project)
    var worktree = try #require(h.worktree(onBranch: "locked"))
    _ = try await h.git.run(["worktree", "lock", worktree.path.path], in: h.project.path)
    await h.model.refresh(h.project)
    worktree = try #require(h.worktree(onBranch: "locked"))
    #expect(worktree.isLocked)

    await h.model.removeWorktree(worktree)

    #expect(h.model.presentedError == nil)
    #expect(h.worktree(onBranch: "locked") == nil, "no record left behind")
    #expect(h.platform.trashed == [worktree.path])
  }

  @Test func aTrashThatRefusesFallsBackToDeletingTheDirectory() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "stuck", basedOn: nil, createBranch: true, in: h.project)
    let worktree = try #require(h.worktree(onBranch: "stuck"))
    h.platform.trash = nil

    await h.model.removeWorktree(worktree)

    #expect(h.model.presentedError == nil)
    #expect(h.worktree(onBranch: "stuck") == nil)
    #expect(!FileManager.default.fileExists(atPath: worktree.path.path), "deleted outright")
    #expect(h.platform.logged.count == 1, "the fallback leaves a line in the log")
  }

  /// The model is on the main actor and a Trash on a network share walks the
  /// whole tree, so the walk must not be where the window's events are.
  @Test func theTrashAndItsFallbackRunOffTheMainThread() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "heavy", basedOn: nil, createBranch: true, in: h.project)
    let worktree = try #require(h.worktree(onBranch: "heavy"))
    h.platform.trash = nil

    await h.model.removeWorktree(worktree)

    #expect(h.platform.trashCallsOnMainThread == [false], "the Trash was asked off the main thread")
    #expect(!FileManager.default.fileExists(atPath: worktree.path.path))
  }

  @Test func aDirectoryThatCanBeNeitherTrashedNorDeletedKeepsTheWorktree() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "pinned", basedOn: nil, createBranch: true, in: h.project)
    let worktree = try #require(h.worktree(onBranch: "pinned"))
    h.platform.trash = nil
    // A read-only parent refuses the unlink of its entries.
    let container = worktree.path.deletingLastPathComponent()
    try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: container.path)
    defer {
      try? FileManager.default.setAttributes(
        [.posixPermissions: 0o755], ofItemAtPath: container.path)
    }

    await h.model.removeWorktree(worktree)

    let alert = try #require(h.model.presentedError)
    #expect(alert.title.hasPrefix("Worktree not removed: the directory could not be moved"))
    #expect(alert.retry == nil)
    #expect(h.worktree(onBranch: "pinned") != nil && h.model.worktreeOperations.isEmpty)
    #expect(FileManager.default.fileExists(atPath: worktree.path.path))
    #expect(h.model.liveTerminalCount == 1, "the shell is still there")
  }
}
