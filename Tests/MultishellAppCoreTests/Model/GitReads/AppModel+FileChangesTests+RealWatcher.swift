import Foundation
import MultishellCore
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

extension AppModelFileChangesTests {
  @Test func aFetchThatBringsACommitReadsAndOneThatFindsNothingDoesNot() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let path = harness.project.path
    try await TestRepository.addOrigin(to: path, in: harness.root, using: harness.git)
    let pusher = harness.root.appending(path: "pusher", directoryHint: .isDirectory)
    _ = try await harness.git.run(
      ["clone", "-q", harness.root.appending(path: "origin.git").path, pusher.path],
      in: harness.root,
    )
    try await TestRepository.commit(
      "upstream",
      files: ["up.txt": "up\n"],
      in: pusher,
      using: harness.git,
    )
    _ = try await harness.git.run(["push", "-q", "origin", "main"], in: pusher)
    let probe = try await RealWatcherProbe(watching: [try common(of: harness), path])
    defer { probe.stop() }
    let fetch = { _ = try await harness.git.run(["fetch", "-q", "origin"], in: path) }

    let bringingACommit = harness.model.fileChangeTargets(try await probe.changes(during: fetch))
    let findingNothing = harness.model.fileChangeTargets(try await probe.changes(during: fetch))

    #expect(bringingACommit.projectsWithGitChanges == [harness.project.id])
    #expect(findingNothing.projectsWithGitChanges.isEmpty)
  }

  /// git's own file monitor writes a cookie under `.git` for every query,
  /// so each of the app's reads raises a change of its own.
  @Test func theFileMonitorsCookiesFromTheAppsReadsCallForNoRead() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let path = harness.project.path
    _ = try await harness.git.run(["config", "core.fsmonitor", "true"], in: path)
    let main = try #require(harness.worktree(onBranch: "main"))
    try harness.dirty(main)
    await harness.model.refreshStatus(of: main.id, forced: true)
    let probe = try await RealWatcherProbe(watching: [try common(of: harness), path])
    defer { probe.stop() }

    let changed = try await probe.changes {
      await harness.model.refreshStatus(of: main.id, forced: true)
    }
    _ = try? await harness.git.run(["fsmonitor--daemon", "stop"], in: path)

    let found = harness.model.fileChangeTargets(changed)
    #expect(found.projectsWithGitChanges.isEmpty)
    #expect(found.fileChangesByWorktree.isEmpty)
  }

  @Test func anEmbeddedRepositorysFileMonitorCookieFromTheAppsReadCallsForNoRead() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let path = harness.project.path
    let sub = path.appending(path: "sub", directoryHint: .isDirectory)
    try await TestRepository.initialise(at: sub, withFirstCommit: true, using: harness.git)
    _ = try await harness.git.run(["config", "core.fsmonitor", "true"], in: sub)
    _ = try await harness.git.run(["add", "sub"], in: path)
    _ = try await harness.git.run(["commit", "-qm", "sub"], in: path)
    let main = try #require(harness.worktree(onBranch: "main"))
    await harness.model.refreshStatus(of: main.id, forced: true)
    let probe = try await RealWatcherProbe(watching: [try common(of: harness), path])
    defer { probe.stop() }

    let changed = try await probe.changes {
      await harness.model.refreshStatus(of: main.id, forced: true)
    }
    _ = try? await harness.git.run(["fsmonitor--daemon", "stop"], in: sub)
    harness.clearStatuses()
    await harness.model.noteFileChanges(changed)

    #expect(harness.model.pendingStatusRefreshes.isEmpty)
  }

  /// The read starts git's monitor, which makes its directory and socket in the
  /// linked worktree's git directory before its first cookie.
  @Test func aLinkedWorktreesFileMonitorStartedByTheAppsReadCallsForNoRead() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let side = try await harness.createWorktree(onBranch: "side")
    _ = try await harness.git.run(["config", "core.fsmonitor", "true"], in: harness.project.path)
    let probe = try await RealWatcherProbe(
      watching: [try common(of: harness), harness.project.path, side.path]
    )
    defer { probe.stop() }

    let changed = try await probe.changes {
      await harness.model.refreshStatus(of: side.id, forced: true)
    }
    _ = try? await harness.git.run(["fsmonitor--daemon", "stop"], in: side.path)
    harness.clearStatuses()
    await harness.model.noteFileChanges(changed)

    #expect(harness.model.pendingStatusRefreshes.isEmpty)
    #expect(harness.model.pendingBranchScans.isEmpty)
  }

  /// A read that wrote under a watched directory would fire the watcher, whose
  /// tick reads again: git spawned for as long as the app is open.
  @Test func theAppsOwnGitReadsRaiseNoFileChange() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let side = try await harness.createWorktree(onBranch: "side")
    _ = try await harness.git.run(["commit", "-q", "--allow-empty", "-m", "ahead"], in: side.path)
    try harness.dirty(side)
    try harness.dirty(try #require(harness.worktree(onBranch: "main")))
    try "changed\n".write(
      to: harness.project.path.appending(path: "README.md"),
      atomically: true,
      encoding: .utf8,
    )
    try Scratch.touch(side.path.appending(path: "README.md"))
    let probe = try await RealWatcherProbe(
      watching: [try common(of: harness), harness.project.path, side.path]
    )
    defer { probe.stop() }

    let changed = try await probe.changes {
      harness.model.statusReadLog.invalidate()
      await harness.model.refreshAll()
      await harness.model.refreshStatus(of: side.id, forced: true)
    }

    #expect(harness.model.mergeStates[side.id] != nil, "the merge read ran too")
    #expect(changed == [])
  }
}
