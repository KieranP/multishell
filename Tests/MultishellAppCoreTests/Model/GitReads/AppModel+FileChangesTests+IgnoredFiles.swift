import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

extension AppModelFileChangesTests {
  private func makeDirectories(_ paths: [String], in worktree: Worktree) throws {
    for path in paths {
      try FileManager.default.createDirectory(
        at: worktree.path.appending(path: path, directoryHint: .isDirectory),
        withIntermediateDirectories: true,
      )
    }
  }

  private func ignore(_ rules: String, in worktree: Worktree) throws {
    try rules.write(
      to: worktree.path.appending(path: ".gitignore"),
      atomically: true,
      encoding: .utf8,
    )
  }

  @Test func aChangeOnlyUnderAnIgnoredDirectoryReadsNoStatus() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    try ignore("node_modules/\n", in: main)
    try makeDirectories(["node_modules/a/lib", "src"], in: main)
    harness.clearStatuses()

    await harness.model.noteFileChanges([
      main.path.appending(path: "node_modules/a/lib"), main.path.appending(path: "node_modules"),
    ])
    #expect(harness.model.pendingStatusRefreshes.isEmpty)

    await harness.model.noteFileChanges([
      main.path.appending(path: "node_modules/a"), main.path.appending(path: "src"),
    ])
    #expect(Set(harness.model.pendingStatusRefreshes.keys) == [main.id])
  }

  @Test func aChangeInAnIgnoredDirectoryHoldingATrackedFileStillReads() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    try ignore("dist\n", in: main)
    try makeDirectories(["dist"], in: main)
    try "x\n".write(
      to: main.path.appending(path: "dist/forced.js"),
      atomically: true,
      encoding: .utf8,
    )
    _ = try await harness.git.run(["add", "-f", "dist/forced.js"], in: main.path)
    harness.clearStatuses()

    await harness.model.noteFileChanges([main.path.appending(path: "dist")])

    #expect(Set(harness.model.pendingStatusRefreshes.keys) == [main.id])
  }

  @Test func editingTheGitignoreAsksGitAgainAboutWhatItIgnores() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    try ignore("node_modules/\n", in: main)
    try makeDirectories(["node_modules/a"], in: main)
    await harness.model.noteFileChanges([main.path.appending(path: "node_modules/a")])
    harness.clearStatuses()

    try ignore("", in: main)
    await harness.model.noteFileChanges([main.path.appending(path: ".gitignore")])
    harness.clearStatuses()
    await harness.model.noteFileChanges([main.path.appending(path: "node_modules/a")])

    #expect(Set(harness.model.pendingStatusRefreshes.keys) == [main.id])
  }

  @Test func aWorktreeInsideADirectoryTheMainOneIgnoresIsStillRead() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    try ignore(".worktrees/\n", in: main)
    let inside = main.path.appending(path: ".worktrees/side", directoryHint: .isDirectory)
    try await harness.addOutsideTheApp("side", at: inside)
    await harness.model.refreshWorktrees(of: harness.project)
    let side = try #require(harness.worktree(onBranch: "side"))
    harness.clearStatuses()

    await harness.model.noteFileChanges([side.path.appending(path: "README.md")])

    #expect(Set(harness.model.pendingStatusRefreshes.keys) == [side.id])
  }

  /// git matches a directory-only pattern against nothing once the directory
  /// is gone, as it is between `npm ci` removing it and the install.
  @Test func anIgnoredDirectoryMissingWhenAskedIsStillIgnoredOnceItIsBack() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    try ignore("node_modules/\n", in: main)
    await harness.model.noteFileChanges([main.path.appending(path: "node_modules")])
    try makeDirectories(["node_modules/a/lib"], in: main)
    harness.clearStatuses()

    await harness.model.noteFileChanges([main.path.appending(path: "node_modules")])

    #expect(harness.model.pendingStatusRefreshes.isEmpty)
  }

  @Test func aGitignoreEditedWhileTheAppIsBehindIsHeededOnReturn() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    try ignore("dist/\n", in: main)
    try makeDirectories(["dist/a"], in: main)
    await harness.model.noteFileChanges([main.path.appending(path: "dist/a")])
    harness.platform.isActive = false
    try ignore("", in: main)
    await harness.model.noteFileChanges([main.path.appending(path: ".gitignore")])

    harness.platform.isActive = true
    await harness.model.refreshAll()
    harness.clearStatuses()
    await harness.model.noteFileChanges([main.path.appending(path: "dist/a")])

    #expect(Set(harness.model.pendingStatusRefreshes.keys) == [main.id])
  }

  @Test func aFileForceAddedUnderADirectoryAlreadyKnownIgnoredIsRead() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    try ignore("dist/\n", in: main)
    try makeDirectories(["dist"], in: main)
    await harness.model.noteFileChanges([main.path.appending(path: "dist")])
    try "x\n".write(to: main.path.appending(path: "dist/f.js"), atomically: true, encoding: .utf8)
    _ = try await harness.git.run(["add", "-f", "dist/f.js"], in: main.path)
    let common = try common(of: harness)
    await harness.model.noteFileChanges([common.appending(path: "index")])
    harness.clearStatuses()

    await harness.model.noteFileChanges([main.path.appending(path: "dist")])

    #expect(Set(harness.model.pendingStatusRefreshes.keys) == [main.id])
  }

  /// `!/gen/` needs a directory, so git calls `gen` ignored while it is gone
  /// and not ignored once a generator writes it again.
  @Test func aWhitelistedDirectoryMissingWhenAskedIsReadOnceItIsBack() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    try ignore("/*\n!/.gitignore\n!/gen/\n", in: main)
    await harness.model.noteFileChanges([main.path.appending(path: "gen")])
    try makeDirectories(["gen"], in: main)
    harness.clearStatuses()

    await harness.model.noteFileChanges([main.path.appending(path: "gen")])

    #expect(Set(harness.model.pendingStatusRefreshes.keys) == [main.id])
  }

  /// A directory swapped in is reported as its parent alone, with no word of
  /// the `.gitignore` it brought.
  @Test func aDirectorySwappedInForgetsWhatGitSaidAboutTheOneItReplaced() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    try makeDirectories(["a/pkg/out", "a/staging/out"], in: main)
    try "out\n".write(
      to: main.path.appending(path: "a/pkg/.gitignore"),
      atomically: true,
      encoding: .utf8,
    )
    await harness.model.noteFileChanges([main.path.appending(path: "a/pkg/out")])
    try FileManager.default.moveItem(
      at: main.path.appending(path: "a/pkg"),
      to: main.path.appending(path: "a/pkg-old"),
    )
    try FileManager.default.moveItem(
      at: main.path.appending(path: "a/staging"),
      to: main.path.appending(path: "a/pkg"),
    )
    await harness.model.noteFileChanges([main.path.appending(path: "a")])
    harness.clearStatuses()

    await harness.model.noteFileChanges([main.path.appending(path: "a/pkg/out")])

    #expect(Set(harness.model.pendingStatusRefreshes.keys) == [main.id])
  }
}
