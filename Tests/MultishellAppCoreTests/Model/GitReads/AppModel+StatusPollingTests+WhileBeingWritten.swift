import Foundation
import MultishellProcess
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit

extension AppModelStatusPollingTests {
  /// A worktree still being set up is a building site: the file lists and
  /// the post-create hook are writing into it. See worktrees.md.
  @Test func aWorktreeWithAStageRunningIsNotBadged() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    try harness.dirty(main)
    harness.model.worktreeOperations.begin(.copyingFiles, on: main.id)

    await harness.model.refreshStatuses()
    #expect(harness.model.statuses[main.id] == nil, "nothing while the stage writes")

    harness.model.worktreeOperations.finish(.copyingFiles, on: main.id)
    await harness.model.refreshStatuses()
    #expect(
      harness.model.statuses[main.id]?.changedFiles == 1, "and the real count once it is done")
  }

  /// A removal's stages run on a worktree whose count holds until the directory
  /// goes. Only a create claims a path whose old reading means nothing.
  @Test func aStageOnAWorktreeThatAlreadyHasABadgeDoesNotBlinkItOff() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    try harness.dirty(main)
    await harness.model.refreshStatuses()
    #expect(harness.model.statuses[main.id]?.changedFiles == 1, "earned before the stage")

    harness.model.worktreeOperations.begin(.removingWorktree, on: main.id)
    await harness.model.refreshStatuses()

    #expect(harness.model.statuses[main.id]?.changedFiles == 1, "kept, as a failed read is kept")
  }

  /// A stage that failed is not still writing, and the pane's Dismiss is the
  /// user's to click: the row says what the tree holds meanwhile.
  @Test func aWorktreeWhoseStageFailedIsBadgedWithoutWaitingForTheDismiss() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    try harness.dirty(main)
    harness.model.worktreeOperations.begin(.postCreateHook, on: main.id)
    harness.model.worktreeOperations.fail(.postCreateHook, on: main.id, message: "no")

    await harness.model.refreshStatuses()

    #expect(harness.model.isBusy(main.id), "still held against a shell")
    #expect(harness.model.statuses[main.id]?.changedFiles == 1)
  }

  /// `git worktree add` writes its record before it checks a file out, and
  /// that directory is watched, so a tick lands the row mid-checkout.
  @Test func aWorktreeHalfwayThroughItsAddIsNotBadged() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    try harness.dirty(main)
    var stale = WorktreeStatus()
    stale.changedFiles = 9
    harness.model.statuses[main.id] = stale
    harness.model.pathClaims.claim(main.id)

    await harness.model.refreshStatuses()
    #expect(
      harness.model.statuses[main.id] == nil, "and the last checkout at this path leaves nothing")

    await harness.model.refreshStatus(of: main.id)
    #expect(harness.model.statuses[main.id] == nil, "a prompt's refresh reads no earlier")
  }

  @Test func aWorktreeAddedOutsideTheAppIsNotReadUntilGitHasMadeIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let gate = harness.root.appendingPathComponent("go")
    defer { try? Data().write(to: gate) }
    let repository = harness.project.path
    try await TestRepository.commit(
      "slow", files: [".gitattributes": "*.dat filter=slow\n", "a.dat": "x\n"], in: repository,
      using: harness.git)
    _ = try await harness.git.run(
      [
        "config", "filter.slow.smudge",
        "while [ ! -f '\(gate.path)' ]; do sleep 0.02; done; cat",
      ], in: repository)
    let outside = harness.root.appendingPathComponent("outside", isDirectory: true)
    let git = harness.git
    let add = Task {
      try await TestRepository.addWorktree(
        onNewBranch: "outside", at: outside, in: repository, using: git)
    }
    let lock = repository.appendingPathComponent(".git/worktrees/outside/locked")
    try await waitUntil { FileManager.default.fileExists(atPath: lock.path) }

    await harness.model.refreshWorktrees(of: harness.project)
    let row = try #require(harness.worktree(onBranch: "outside"))
    await harness.model.refreshStatuses()
    #expect(harness.model.statuses[row.id] == nil)

    try Data().write(to: gate)
    _ = try await add.value
    await harness.model.refreshWorktrees(of: harness.project)
    await harness.model.refreshStatuses()
    #expect(harness.model.statuses[row.id] != nil)
  }

  /// Only the lock's age tells a dead add from a running one, and time passing
  /// changes nothing in the records a watcher tick compares.
  @Test func aCreateKilledMidCheckoutGetsItsBadgeBackOnceItsLockIsOld() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    await harness.model.createWorktree(
      branch: "killed", basedOn: nil, createsBranch: true, in: harness.project)
    let lock = harness.project.path.appendingPathComponent(".git/worktrees/killed/locked")
    try "initializing".write(to: lock, atomically: true, encoding: .utf8)
    await harness.model.refreshWorktrees(of: harness.project)
    let killed = try #require(harness.worktree(onBranch: "killed"))
    #expect(killed.isInitializing)
    try FileManager.default.setAttributes(
      [.modificationDate: Date(timeIntervalSinceNow: -3600)], ofItemAtPath: lock.path)

    await harness.model.refreshProjectsIfChanged()
    await harness.model.pollRound()

    #expect(harness.worktree(onBranch: "killed")?.isInitializing == false)
    #expect(harness.model.statuses[killed.id] != nil)
  }

  /// The plain create, no file lists and no hook: nothing but the `defer`
  /// lets go of the path, and a row never let go of is never badged again.
  @Test func aCreateWithNoStagesAfterItLetsGoOfTheRow() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }

    await harness.model.createWorktree(
      branch: "plain", basedOn: nil, createsBranch: true, in: harness.project)

    let created = try #require(harness.worktree(onBranch: "plain"))
    #expect(!harness.model.pathClaims.isClaimed(created.id))
    try harness.dirty(created)

    await harness.model.refreshStatuses()

    #expect(harness.model.statuses[created.id]?.changedFiles == 1)
  }

  /// The planned path is claimed before git has agreed to it, so a create
  /// bound to fail must not blank the row already at that path.
  @Test func aCreateAimedAtAnExistingRowLeavesItsBadgeAlone() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    try harness.dirty(main)
    await harness.model.refreshStatuses()

    #expect(harness.model.claimPath(main.path) == nil)
    #expect(!harness.model.isBeingWritten(main.id))
    await harness.model.refreshStatuses()
    #expect(harness.model.statuses[main.id]?.changedFiles == 1)
  }

  /// A file list is the one stage whose `endSetup` runs before its entry is
  /// cleared, so the read it schedules must judge the row later, not then.
  @Test func aCreateWithOnlyAFileListGetsItsBadgeWithoutWaitingForThePoll() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    try "secret".write(
      to: harness.project.path.appendingPathComponent(".env"), atomically: true, encoding: .utf8)
    harness.model.setSettings(ProjectSettings(copiedPaths: ".env"), for: harness.project)

    await harness.model.createWorktree(
      branch: "listed", basedOn: nil, createsBranch: true, in: harness.project)
    let created = try #require(harness.worktree(onBranch: "listed"))
    await harness.model.stageHandles.setupTask(of: created.id)?.value
    #expect(harness.model.worktreeOperations.isEmpty, "the copy is done")

    try await waitUntil({ harness.model.statuses[created.id] != nil }, seconds: 2)

    #expect(harness.model.statuses[created.id]?.changedFiles == 1, "the copied .env, read at once")
  }

  /// The whole of what was reported: a post-create hook writing a build
  /// directory used to badge the row with what it had written so far.
  @Test func aPostCreateHookStillWritingDoesNotBadgeTheRow() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let gate = harness.root.appendingPathComponent("go")
    harness.model.setSettings(
      ProjectSettings(
        postCreateHook: """
          mkdir -p build && echo x > build/one && echo x > build/two
          while [ ! -f "\(gate.path)" ]; do sleep 0.02; done
          """), for: harness.project)

    await harness.model.createWorktree(
      branch: "slow", basedOn: nil, createsBranch: true, in: harness.project)
    let created = try #require(harness.worktree(onBranch: "slow"))
    let two = created.path.appendingPathComponent("build/two").path
    try await waitUntil({ FileManager.default.fileExists(atPath: two) }, seconds: 4)

    await harness.model.refreshStatuses()
    #expect(harness.model.statuses[created.id] == nil, "nothing while the hook writes")

    try Data().write(to: gate)
    await harness.model.stageHandles.setupTask(of: created.id)?.value
    await harness.model.refreshStatuses()

    #expect(
      harness.model.statuses[created.id]?.changedFiles == 1, "the one untracked directory, after")
  }
}
