import Foundation
import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit
@testable import MultishellProcess

extension AppModelWorktreeListRefreshTests {
  /// Paths are ids, so a leftover badge and commit date would pass to the next
  /// worktree at that path, saying a branch has landed when it has not.
  @Test func aWorktreeRemovedOutsideTheAppTakesItsMergedBadgeAndCommitDateWithIt() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "gone", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "gone"))

    h.model.mergeStates[created.id] = .merged(.ancestor, into: "main")
    h.model.lastCommitDates[created.id] = Date(timeIntervalSince1970: 1000)

    _ = try await h.git.run(
      ["worktree", "remove", "--force", created.path.path], in: h.project.path)
    await h.model.refreshWorktrees(of: h.project)

    #expect(h.worktree(onBranch: "gone") == nil, "git no longer lists it")
    #expect(h.model.mergeStates[created.id] == nil)
    #expect(h.model.lastCommitDates[created.id] == nil)
    #expect(h.model.mergeChecks[created.id] == nil)
  }

  /// Identity is the path, so a worktree made where one was removed takes
  /// its id, and with it whatever badge was left over.
  @Test func aWorktreeRemovedOutsideTheAppTakesItsStatusBadgeWithIt() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let path = h.root.appendingPathComponent("demo-feature", isDirectory: true)
    _ = try await h.git.run(
      ["worktree", "add", "-b", "feature", path.path], in: h.project.path)
    await h.model.refreshWorktrees(of: h.project)
    let feature = try #require(h.worktree(onBranch: "feature"))
    try "work\n".write(
      to: path.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
    await h.model.refreshStatuses()
    #expect(h.model.statuses[feature.id]?.changedFiles == 1)

    _ = try await h.git.run(["worktree", "remove", "--force", path.path], in: h.project.path)
    await h.model.refreshWorktrees(of: h.project)

    #expect(h.model.statuses[feature.id] == nil, "the reading went with the worktree")
  }

  /// The reads run while the app carries on, so a worktree can be removed
  /// between asking git and hearing back.
  @Test func aWorktreeRemovedWhileGitRanGetsNoBadgeFromThatRound() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let path = h.root.appendingPathComponent("demo-gone", isDirectory: true)
    _ = try await h.git.run(["worktree", "add", "-b", "gone", path.path], in: h.project.path)
    await h.model.refreshWorktrees(of: h.project)
    let doomed = try #require(h.worktree(onBranch: "gone"))
    let main = try #require(h.worktree(onBranch: "main"))
    // A git slow enough that the removal lands while the round is inside it.
    let slow = try h.modelOnFakeGit(
      """
      while [ "${1#--}" != "$1" ]; do shift; done
      case "$1" in
        status) sleep 1; printf '## main\\n M a.txt\\n' ;;
      esac
      """)

    let round = Task { await slow.refreshStatuses() }
    try await Task.sleep(for: .milliseconds(200))
    h.store.replaceWorktrees([main], forProject: h.project.id)
    await round.value

    #expect(slow.statuses[main.id] != nil, "the round landed, so there is something to judge")
    #expect(slow.statuses[doomed.id] == nil, "a row that has gone keeps no reading")
  }

  @Test func aWorktreeThatGoesTakesItsUntrackedLineCountsWithIt() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    h.model.setGitStatusIndicator(.stagedAndUnstaged)
    await h.model.createWorktree(branch: "side", basedOn: nil, createBranch: true, in: h.project)
    let side = try #require(h.worktree(onBranch: "side"))
    try "a\nb\n".write(
      to: side.path.appendingPathComponent("new.txt"), atomically: true, encoding: .utf8)
    await h.model.refreshStatus(of: side.id, forced: true)
    let memo = try #require(h.model.coordinator).git.readState.untrackedMemo
    #expect(!memo.entries(in: side.path).isEmpty)

    _ = try await h.git.run(
      ["worktree", "remove", "--force", side.path.path], in: h.project.path)
    await h.model.refreshWorktrees(of: h.project)

    #expect(h.worktree(onBranch: "side") == nil)
    #expect(memo.entries(in: side.path).isEmpty)
  }

  @Test func aRemovalDialogClosesWhenGitStopsListingItsWorktree() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "asked", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "asked"))
    await h.model.requestWorktreeRemoval(of: created)?.value
    #expect(h.model.pendingWorktreeRemoval?.id == created.id)

    _ = try await h.git.run(
      ["worktree", "remove", "--force", created.path.path], in: h.project.path)
    await h.model.refreshWorktrees(of: h.project)

    #expect(h.model.workspace.worktree(created.id) == nil)
    #expect(
      h.model.pendingWorktreeRemoval == nil, "Confirm would remove a path git no longer lists")
  }

  /// A refresh drops the vanished worktree's tabs and sessions, and without
  /// a reconcile the host keeps the surfaces and the shells run on unreachable.
  @Test func aWorktreeRemovedOutsideTheAppTakesItsShellsWithIt() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "gone", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "gone"))
    let sessions = Set(h.model.workspace.sessions(in: created.id).map(\.id))
    #expect(h.engine.liveSessionIDs == sessions)

    _ = try await h.git.run(
      ["worktree", "remove", "--force", created.path.path], in: h.project.path)
    h.engine.focused.removeAll()
    await h.model.refreshWorktrees(of: h.project)

    #expect(h.model.workspace.worktree(created.id) == nil)
    #expect(h.engine.liveSessionIDs.isEmpty, "the shells outlived the row they belonged to")
    #expect(Set(h.engine.closed) == sessions)
    #expect(
      h.engine.focused.isEmpty,
      "a poll must not pull the keyboard out of what the user is typing in")
  }

  /// The worktree goes in a terminal instead: the tick drops the row, and
  /// the hook running there has no pane left to Cancel from, so it is ended.
  @Test func aWorktreeRemovedOutsideTheAppEndsTheHookStillRunningInIt() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    h.model.updateSettings(ProjectSettings(postCreateHook: "sleep 30; exit 1"), for: h.project)

    await h.model.createWorktree(branch: "setup", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "setup"))
    #expect(h.model.worktreeOperations[created.id]?.isRunning == true)
    let setup = h.model.stageHandles.setup(of: created.id)
    let began = ContinuousClock.now

    _ = try await h.git.run(
      ["worktree", "remove", "--force", created.path.path], in: h.project.path)
    await h.model.refreshWorktrees(of: h.project)
    #expect(h.worktree(onBranch: "setup") == nil, "git no longer lists it")
    await setup?.value

    #expect(h.model.worktreeOperations[created.id] == nil)
    #expect(h.model.stageHandles.setup(of: created.id) == nil)
    #expect(h.model.stageHandles.stopper(of: created.id) == nil)
    #expect(ContinuousClock.now - began < .seconds(12), "signalled, not waited out")
    #expect(h.model.presentedError == nil, "a worktree that is not there has nothing to report")
  }
}
