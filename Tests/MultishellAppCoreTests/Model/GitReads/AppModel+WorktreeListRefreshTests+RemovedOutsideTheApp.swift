import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit
@testable import MultishellProcess

extension AppModelWorktreeListRefreshTests {
  /// Paths are ids, so a leftover badge and commit date would pass to the next
  /// worktree at that path, saying a branch has landed when it has not.
  @Test func aWorktreeRemovedOutsideTheAppTakesItsMergedBadgeAndCommitDateWithIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    await harness.model.createWorktree(
      branch: "gone", basedOn: nil, createsBranch: true, in: harness.project)
    let created = try #require(harness.worktree(onBranch: "gone"))

    harness.model.mergeStates[created.id] = .merged(.ancestor, into: "main")
    harness.model.lastCommitDates[created.id] = Date(timeIntervalSince1970: 1000)

    try await harness.removeOutsideTheApp(created.path)
    await harness.model.refreshWorktrees(of: harness.project)

    #expect(harness.worktree(onBranch: "gone") == nil, "git no longer lists it")
    #expect(harness.model.mergeStates[created.id] == nil)
    #expect(harness.model.lastCommitDates[created.id] == nil)
    #expect(harness.model.mergeVerdictBases[created.id] == nil)
  }

  /// Identity is the path, so a worktree made where one was removed takes
  /// its id, and with it whatever badge was left over.
  @Test func aWorktreeRemovedOutsideTheAppTakesItsStatusBadgeWithIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let path = harness.root.appendingPathComponent("demo-feature", isDirectory: true)
    try await harness.addOutsideTheApp("feature", at: path)
    await harness.model.refreshWorktrees(of: harness.project)
    let feature = try #require(harness.worktree(onBranch: "feature"))
    try harness.dirty(feature)
    await harness.model.refreshStatuses()
    #expect(harness.model.statuses[feature.id]?.changedFiles == 1)

    try await harness.removeOutsideTheApp(path)
    await harness.model.refreshWorktrees(of: harness.project)

    #expect(harness.model.statuses[feature.id] == nil, "the reading went with the worktree")
  }

  @Test func aWorktreeThatGoesTakesItsUntrackedLineCountsWithIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.setGitStatusIndicator(.stagedAndUnstaged)
    await harness.model.createWorktree(
      branch: "side", basedOn: nil, createsBranch: true, in: harness.project)
    let side = try #require(harness.worktree(onBranch: "side"))
    try "a\nb\n".write(
      to: side.path.appendingPathComponent("new.txt"), atomically: true, encoding: .utf8)
    await harness.model.refreshStatus(of: side.id, forced: true)
    let memo = try #require(harness.model.coordinator).git.readState.untrackedMemo
    #expect(!memo.entries(in: side.path).isEmpty)

    try await harness.removeOutsideTheApp(side.path)
    await harness.model.refreshWorktrees(of: harness.project)

    #expect(harness.worktree(onBranch: "side") == nil)
    #expect(memo.entries(in: side.path).isEmpty)
  }

  @Test func aRemovalDialogClosesWhenGitStopsListingItsWorktree() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    await harness.model.createWorktree(
      branch: "asked", basedOn: nil, createsBranch: true, in: harness.project)
    let created = try #require(harness.worktree(onBranch: "asked"))
    await harness.model.requestWorktreeRemoval(of: created)?.value
    #expect(harness.model.pendingWorktreeRemoval?.id == created.id)

    try await harness.removeOutsideTheApp(created.path)
    await harness.model.refreshWorktrees(of: harness.project)

    #expect(harness.model.workspace.worktree(created.id) == nil)
    #expect(
      harness.model.pendingWorktreeRemoval == nil, "Confirm would remove a path git no longer lists"
    )
  }

  /// A refresh drops the vanished worktree's tabs and sessions, and without
  /// a reconcile the host keeps the surfaces and the shells run on unreachable.
  @Test func aWorktreeRemovedOutsideTheAppTakesItsShellsWithIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    await harness.model.createWorktree(
      branch: "gone", basedOn: nil, createsBranch: true, in: harness.project)
    let created = try #require(harness.worktree(onBranch: "gone"))
    let sessions = Set(harness.model.workspace.sessions(in: created.id).map(\.id))
    #expect(harness.engine.liveSessionIDs == sessions)

    try await harness.removeOutsideTheApp(created.path)
    harness.engine.focused.removeAll()
    await harness.model.refreshWorktrees(of: harness.project)

    #expect(harness.model.workspace.worktree(created.id) == nil)
    #expect(harness.engine.liveSessionIDs.isEmpty, "the shells outlived the row they belonged to")
    #expect(Set(harness.engine.closed) == sessions)
    #expect(
      harness.engine.focused.isEmpty,
      "a poll must not pull the keyboard out of what the user is typing in")
  }

  /// The worktree goes in a terminal instead: the tick drops the row, and
  /// the hook running there has no pane left to Cancel from, so it is ended.
  @Test func aWorktreeRemovedOutsideTheAppEndsTheHookStillRunningInIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.setSettings(
      ProjectSettings(postCreateHook: "sleep 30; exit 1"), for: harness.project)

    await harness.model.createWorktree(
      branch: "setup", basedOn: nil, createsBranch: true, in: harness.project)
    let created = try #require(harness.worktree(onBranch: "setup"))
    #expect(harness.model.worktreeOperations[created.id]?.isRunning == true)
    let setup = harness.model.stageHandles.setup(of: created.id)
    let began = ContinuousClock.now

    try await harness.removeOutsideTheApp(created.path)
    await harness.model.refreshWorktrees(of: harness.project)
    #expect(harness.worktree(onBranch: "setup") == nil, "git no longer lists it")
    await setup?.value

    #expect(harness.model.worktreeOperations[created.id] == nil)
    #expect(harness.model.stageHandles.setup(of: created.id) == nil)
    #expect(harness.model.stageHandles.stopper(of: created.id) == nil)
    #expect(ContinuousClock.now - began < .seconds(12), "signalled, not waited out")
    #expect(
      harness.model.presentedError == nil, "a worktree that is not there has nothing to report")
  }
}
