import Foundation
import MultishellCore
import MultishellProcess
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

extension AppModelStatusPollingTests {
  /// A worktree still being set up is a building site: the file lists and
  /// the post-create hook are writing into it. See worktrees.md.
  @Test func aWorktreeWithAStageRunningIsNotBadged() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let main = try #require(h.worktree(onBranch: "main"))
    try "x".write(
      to: main.path.appendingPathComponent("dirty.txt"), atomically: true, encoding: .utf8)
    h.model.worktreeOperations.begin(.copyingFiles, on: main.id)

    await h.model.refreshStatuses()
    #expect(h.model.statuses[main.id] == nil, "nothing while the stage writes")

    h.model.worktreeOperations.finish(.copyingFiles, on: main.id)
    await h.model.refreshStatuses()
    #expect(h.model.statuses[main.id]?.changedFiles == 1, "and the real count once it is done")
  }

  /// A removal's stages run on a worktree whose count holds until the directory
  /// goes. Only a create claims a path whose old reading means nothing.
  @Test func aStageOnAWorktreeThatAlreadyHasABadgeDoesNotBlinkItOff() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let main = try #require(h.worktree(onBranch: "main"))
    try "x".write(
      to: main.path.appendingPathComponent("dirty.txt"), atomically: true, encoding: .utf8)
    await h.model.refreshStatuses()
    #expect(h.model.statuses[main.id]?.changedFiles == 1, "earned before the stage")

    h.model.worktreeOperations.begin(.removingWorktree, on: main.id)
    await h.model.refreshStatuses()

    #expect(h.model.statuses[main.id]?.changedFiles == 1, "kept, as a failed read is kept")
  }

  /// A stage that failed is not still writing, and the pane's Dismiss is the
  /// user's to click: the row says what the tree holds meanwhile.
  @Test func aWorktreeWhoseStageFailedIsBadgedWithoutWaitingForTheDismiss() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let main = try #require(h.worktree(onBranch: "main"))
    try "x".write(
      to: main.path.appendingPathComponent("dirty.txt"), atomically: true, encoding: .utf8)
    h.model.worktreeOperations.begin(.postCreateHook, on: main.id)
    h.model.worktreeOperations.fail(.postCreateHook, on: main.id, message: "no")

    await h.model.refreshStatuses()

    #expect(h.model.isBusy(main.id), "still held against a shell")
    #expect(h.model.statuses[main.id]?.changedFiles == 1)
  }

  /// `git worktree add` writes its record before it checks a file out, and
  /// that directory is watched, so a tick lands the row mid-checkout.
  @Test func aWorktreeHalfwayThroughItsAddIsNotBadged() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let main = try #require(h.worktree(onBranch: "main"))
    try "x".write(
      to: main.path.appendingPathComponent("dirty.txt"), atomically: true, encoding: .utf8)
    var stale = WorktreeStatus()
    stale.changedFiles = 9
    h.model.statuses[main.id] = stale
    h.model.pathClaims.claim(main.id)

    await h.model.refreshStatuses()
    #expect(h.model.statuses[main.id] == nil, "and the last checkout at this path leaves nothing")

    await h.model.refreshStatus(of: main.id)
    #expect(h.model.statuses[main.id] == nil, "a prompt's refresh reads no earlier")
  }

  @Test func aWorktreeAddedOutsideTheAppIsNotReadUntilGitHasMadeIt() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let gate = h.root.appendingPathComponent("go")
    defer { try? Data().write(to: gate) }
    let repository = h.project.path
    try await TestRepository.commit(
      "slow", files: [".gitattributes": "*.dat filter=slow\n", "a.dat": "x\n"], in: repository,
      using: h.git)
    _ = try await h.git.run(
      [
        "config", "filter.slow.smudge",
        "while [ ! -f '\(gate.path)' ]; do sleep 0.02; done; cat",
      ], in: repository)
    let outside = h.root.appendingPathComponent("outside", isDirectory: true)
    let git = h.git
    let add = Task {
      try await git.run(["worktree", "add", "-q", "-b", "outside", outside.path], in: repository)
    }
    let lock = repository.appendingPathComponent(".git/worktrees/outside/locked")
    try await waitUntil { FileManager.default.fileExists(atPath: lock.path) }

    await h.model.refresh(h.project)
    let row = try #require(h.worktree(onBranch: "outside"))
    await h.model.refreshStatuses()
    #expect(h.model.statuses[row.id] == nil)

    try Data().write(to: gate)
    _ = try await add.value
    await h.model.refresh(h.project)
    await h.model.refreshStatuses()
    #expect(h.model.statuses[row.id] != nil)
  }

  /// Only the lock's age tells a dead add from a running one, and time passing
  /// changes nothing in the records a watcher tick compares.
  @Test func aCreateKilledMidCheckoutGetsItsBadgeBackOnceItsLockIsOld() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "killed", basedOn: nil, createBranch: true, in: h.project)
    let lock = h.project.path.appendingPathComponent(".git/worktrees/killed/locked")
    try "initializing".write(to: lock, atomically: true, encoding: .utf8)
    await h.model.refresh(h.project)
    let killed = try #require(h.worktree(onBranch: "killed"))
    #expect(killed.isInitializing)
    try FileManager.default.setAttributes(
      [.modificationDate: Date(timeIntervalSinceNow: -3600)], ofItemAtPath: lock.path)

    await h.model.refreshWorktreesIfRecordsChanged()
    await h.model.pollRound()

    #expect(h.worktree(onBranch: "killed")?.isInitializing == false)
    #expect(h.model.statuses[killed.id] != nil)
  }

  /// The plain create, no file lists and no hook: nothing but the `defer`
  /// lets go of the path, and a row never let go of is never badged again.
  @Test func aCreateWithNoStagesAfterItLetsGoOfTheRow() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }

    await h.model.createWorktree(branch: "plain", basedOn: nil, createBranch: true, in: h.project)

    let created = try #require(h.worktree(onBranch: "plain"))
    #expect(!h.model.pathClaims.isClaimed(created.id))
    try "x".write(
      to: created.path.appendingPathComponent("dirty.txt"), atomically: true, encoding: .utf8)

    await h.model.refreshStatuses()

    #expect(h.model.statuses[created.id]?.changedFiles == 1)
  }

  /// Nothing in the model stops two creates overlapping, so each holds its
  /// own row: one slot would leave whichever started first badged mid-add.
  @Test func twoCreatesAtOnceEachHoldTheirOwnRow() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let gate = h.root.appendingPathComponent("go")
    h.model.updateSettings(
      ProjectSettings(preCreateHook: "while [ ! -f \"\(gate.path)\" ]; do sleep 0.02; done"),
      for: h.project)

    func planned(_ branch: String) throws -> Worktree.ID {
      try #require(h.model.plannedPath(forBranch: branch, createBranch: true, in: h.project))
        .standardizedFileURL.path
    }
    let plannedOne = try planned("one")
    let plannedTwo = try planned("two")
    let first = Task {
      await h.model.createWorktree(branch: "one", basedOn: nil, createBranch: true, in: h.project)
    }
    let second = Task {
      await h.model.createWorktree(branch: "two", basedOn: nil, createBranch: true, in: h.project)
    }
    let claims = { h.model.pathClaims }
    try await waitUntil(
      { claims().isClaimed(plannedOne) && claims().isClaimed(plannedTwo) }, seconds: 5)
    #expect(claims().isClaimed(plannedOne) && claims().isClaimed(plannedTwo), "both, not the later")

    try Data().write(to: gate)
    await first.value
    await second.value

    #expect(!claims().isClaimed(plannedOne) && !claims().isClaimed(plannedTwo), "each let go")
    let one = try #require(h.worktree(onBranch: "one"))
    let two = try #require(h.worktree(onBranch: "two"))
    #expect([one.id, two.id] == [plannedOne, plannedTwo], "what was held is what git listed")
  }

  /// The planned path is claimed before git has agreed to it, so a create
  /// bound to fail must not blank the row already at that path.
  @Test func aCreateAimedAtAnExistingRowLeavesItsBadgeAlone() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let main = try #require(h.worktree(onBranch: "main"))
    try "x".write(
      to: main.path.appendingPathComponent("dirty.txt"), atomically: true, encoding: .utf8)
    await h.model.refreshStatuses()

    #expect(h.model.claimConstruction(of: main.path) == nil)
    #expect(!h.model.isUnderConstruction(main.id))
    await h.model.refreshStatuses()
    #expect(h.model.statuses[main.id]?.changedFiles == 1)
  }

  /// Two creates naming one path, one of them doomed: the first to end
  /// must not let go of a path the other is still checking out into.
  @Test func twoCreatesOnOnePathHoldItUntilTheLastLetsGo() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let planned = h.root.appendingPathComponent("twice", isDirectory: true)
    let id = try #require(h.model.claimConstruction(of: planned))
    #expect(h.model.claimConstruction(of: planned) == id)

    h.model.releaseConstruction(of: id, in: h.project)
    #expect(h.model.isUnderConstruction(id), "one still holds it")

    h.model.releaseConstruction(of: id, in: h.project)
    #expect(!h.model.isUnderConstruction(id))
  }

  /// A file list is the one stage whose `endSetup` runs before its entry is
  /// cleared, so the read it schedules must judge the row later, not then.
  @Test func aCreateWithOnlyAFileListGetsItsBadgeWithoutWaitingForThePoll() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    try "secret".write(
      to: h.project.path.appendingPathComponent(".env"), atomically: true, encoding: .utf8)
    h.model.updateSettings(ProjectSettings(copiedPaths: ".env"), for: h.project)

    await h.model.createWorktree(branch: "listed", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "listed"))
    await h.model.stageHandles.setup(of: created.id)?.value
    #expect(h.model.worktreeOperations.isEmpty, "the copy is done")

    try await waitUntil({ h.model.statuses[created.id] != nil }, seconds: 2)

    #expect(h.model.statuses[created.id]?.changedFiles == 1, "the copied .env, read at once")
  }

  /// The whole of what was reported: a post-create hook writing a build
  /// directory used to badge the row with what it had written so far.
  @Test func aPostCreateHookStillWritingDoesNotBadgeTheRow() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let gate = h.root.appendingPathComponent("go")
    h.model.updateSettings(
      ProjectSettings(
        postCreateHook: """
          mkdir -p build && echo x > build/one && echo x > build/two
          while [ ! -f "\(gate.path)" ]; do sleep 0.02; done
          """), for: h.project)

    await h.model.createWorktree(branch: "slow", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "slow"))
    let two = created.path.appendingPathComponent("build/two").path
    try await waitUntil({ FileManager.default.fileExists(atPath: two) }, seconds: 4)

    await h.model.refreshStatuses()
    #expect(h.model.statuses[created.id] == nil, "nothing while the hook writes")

    try Data().write(to: gate)
    await h.model.stageHandles.setup(of: created.id)?.value
    await h.model.refreshStatuses()

    #expect(h.model.statuses[created.id]?.changedFiles == 1, "the one untracked directory, after")
  }
}
