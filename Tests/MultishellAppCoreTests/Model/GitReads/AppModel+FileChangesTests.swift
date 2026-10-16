import Foundation
import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite(.serialized) @MainActor
struct AppModelFileChangesTests {
  func common(of harness: GitHarness) throws -> URL {
    try #require(harness.model.commonGitDirectories[harness.project.id])
  }

  @Test func aCheckoutInTheMainWorktreeMovesItsRowWhenTheWatcherReportsTheGitDirectory()
    async throws
  {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    _ = try await harness.createWorktree(onBranch: "side")
    _ = try await harness.git.run(["checkout", "-q", "-b", "elsewhere"], in: harness.project.path)

    harness.watcher.onChange?([try common(of: harness)])

    try await waitUntil { harness.worktree(onBranch: "elsewhere") != nil }
    #expect(harness.worktree(onBranch: "elsewhere") != nil)
    #expect(harness.worktree(onBranch: "main") == nil)
  }

  @Test func anEditInALinkedWorktreeReadsThatWorktreeAlone() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let side = try await harness.createWorktree(onBranch: "side")
    let main = try #require(harness.worktree(onBranch: "main"))
    try harness.dirty(side)
    harness.clearStatuses()

    await harness.model.noteFileChanges([side.path])

    #expect(Set(harness.model.pendingStatusRefreshes.keys) == [side.id])
    try await waitUntil { harness.model.statuses[side.id] != nil }
    #expect(harness.model.statuses[side.id]?.changedFiles == 1)
    #expect(harness.model.statuses[main.id] == nil)
  }

  @Test func aChangeInTheGitDirectoryReadsEveryRowOfItsProject() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let side = try await harness.createWorktree(onBranch: "side")
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.clearStatuses()

    await harness.model.noteFileChanges([try common(of: harness).appending(path: "worktrees")])

    #expect(Set(harness.model.pendingStatusRefreshes.keys) == [side.id, main.id])
    #expect(harness.model.pendingBranchScans[harness.project.id] != nil)
  }

  @Test func aChangeToGitsObjectsReadsNothing() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.clearStatuses()

    await harness.model.noteFileChanges([try common(of: harness).appending(path: "objects")])

    #expect(harness.model.pendingStatusRefreshes.isEmpty)
    #expect(harness.model.pendingBranchScans.isEmpty)
  }

  @Test func anEditAsksGitNothingAboutAProjectWhoseGitDirectoryIsUnknown() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let model = try harness.modelOnFakeGit(
      """
      case "$*" in *rev-parse*) exit 128 ;; esac
      exit 0
      """
    )
    model.commonGitDirectories = [:]

    await model.noteFileChanges([harness.project.path.appending(path: "src")])

    #expect(harness.gitCalls().filter { $0.contains("rev-parse") } == [])
  }

  @Test func aChangeMadeInTheBackgroundIsReadOnReturnThoughThePaceHeldItBack() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.statusReadLog.pace = StatusReadPace(minimumGap: .seconds(2), costMultiple: 0)
    let main = try #require(harness.worktree(onBranch: "main"))
    await harness.model.refreshStatus(of: main.id, forced: true)
    harness.platform.isActive = false
    try harness.dirty(main)
    await harness.model.noteFileChanges([main.path])

    harness.platform.isActive = true
    await harness.model.refreshAll()

    try await waitUntil { harness.model.statuses[main.id]?.changedFiles == 1 }
    #expect(harness.model.statuses[main.id]?.changedFiles == 1)
  }

  @Test func aReadQueuedWhileInFrontDoesNotRunOnceTheAppLeavesIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.statusReadLog.pace = StatusReadPace(
      minimumGap: .milliseconds(800),
      costMultiple: 0,
    )
    let main = try #require(harness.worktree(onBranch: "main"))
    await harness.model.refreshStatus(of: main.id, forced: true)
    try harness.dirty(main)
    await harness.model.noteFileChanges([main.path])
    let queued = try #require(harness.model.pendingStatusRefreshes[main.id])

    harness.platform.isActive = false
    await queued.value

    #expect(harness.model.statuses[main.id]?.changedFiles == 0)
  }

  @Test func aWorktreeTheBranchCheckListsIsWatched() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let outside = harness.root.appending(path: "outside", directoryHint: .isDirectory)
    try await harness.addOutsideTheApp("outside", at: outside)
    _ = try await harness.git.run(["checkout", "-q", "-b", "elsewhere"], in: harness.project.path)
    let main = try #require(harness.worktree(onBranch: "main"))

    await harness.model.refreshStatus(of: main.id, forced: true)
    #expect(harness.worktree(onBranch: "outside") != nil, "listed by the branch check")
    await harness.model.noteFileChanges([try common(of: harness).appending(path: "worktrees")])

    let added = try #require(harness.worktree(onBranch: "outside"))
    #expect(harness.watcher.watched.contains(added.path))
  }

  @Test func aChangeWhileTheAppIsInTheBackgroundReadsNoStatus() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.clearStatuses()
    harness.platform.isActive = false

    await harness.model.noteFileChanges([main.path.appending(path: "src")])

    #expect(harness.model.pendingStatusRefreshes.isEmpty)
  }

  @Test func aChangeBeforeThePaceAllowsAReadIsReadOnceItDoes() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.statusReadLog.pace = StatusReadPace(
      minimumGap: .milliseconds(600),
      costMultiple: 0,
    )
    let main = try #require(harness.worktree(onBranch: "main"))
    await harness.model.refreshStatus(of: main.id)
    try harness.dirty(main)

    harness.model.scheduleStatusRefresh(of: main.id)

    try await waitUntil { harness.model.statuses[main.id]?.changedFiles == 1 }
    #expect(harness.model.statuses[main.id]?.changedFiles == 1)
  }

  @Test func furtherChangesWhileAReadIsQueuedQueueNoOther() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.clearStatuses()

    harness.model.scheduleStatusRefresh(of: main.id)
    let queued = try #require(harness.model.pendingStatusRefreshes[main.id])
    harness.model.scheduleStatusRefresh(of: main.id)

    #expect(harness.model.pendingStatusRefreshes[main.id] == queued)
    await queued.value
  }
}
