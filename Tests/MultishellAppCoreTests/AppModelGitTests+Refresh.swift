import Foundation
import MultishellCore
import MultishellGitKit
import Testing

@testable import MultishellAppCore

/// What a watcher tick, a status poll and an explicit Refresh do to the
/// sidebar, including the repositories git can no longer read.
extension AppModelGitTests {
  @Test func aWorktreeAddedOutsideTheAppIsFoundByTheWatcherTick() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let outside = h.root.appendingPathComponent("outside", isDirectory: true)
    _ = try await h.git.run(
      ["worktree", "add", "-q", "-b", "outside", outside.path], in: h.project.path)

    await h.model.refreshWorktreesIfRecordsChanged()

    #expect(h.worktree(onBranch: "outside") != nil)
    #expect(h.watcher.watched.map(\.lastPathComponent).sorted() == ["outside", "worktrees"])
  }

  /// A prompt's status refresh is in flight when the worktree goes. Its
  /// answer must not badge a row that is not there, or one re-made at the
  /// same path, paths being ids.
  @Test func aStatusThatArrivesAfterTheWorktreeWentBadgesNothing() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let main = h.model.workspace.worktrees(of: h.project.id)[0]
    try "x".write(
      to: main.path.appendingPathComponent("dirty.txt"), atomically: true, encoding: .utf8)

    let refresh = Task { await h.model.refreshStatus(of: main.id) }
    // One turn: the refresh has asked git and is waiting on the answer.
    await Task.yield()
    h.store.replaceWorktrees([], forProject: h.project.id)
    await refresh.value

    #expect(h.model.statuses[main.id] == nil)
  }

  @Test func aBranchSwitchInTheMainWorktreeIsCaughtByTheStatusPoll() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    _ = try await h.git.run(["checkout", "-q", "-b", "elsewhere"], in: h.project.path)
    #expect(h.worktree(onBranch: "main") != nil, "nothing has looked yet")

    await h.model.refreshStatuses()

    #expect(h.worktree(onBranch: "elsewhere") != nil)
    #expect(h.worktree(onBranch: "main") == nil)
    let statuses = h.model.statuses
    #expect(statuses.count == 1 && statuses.values.first?.branch == "elsewhere")
  }

  @Test func aRefreshLandingAfterTheProjectWasRemovedLeavesNoTrace() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let project = h.project
    #expect(h.model.worktreeRecords[project.id] != nil)

    h.model.removeProject(project)
    await h.model.refresh(project)

    #expect(h.model.workspace.projects.isEmpty)
    #expect(h.model.workspace.worktrees.isEmpty)
    #expect(h.model.worktreeRecords[project.id] == nil)
    #expect(h.model.commonGitDirectories[project.id] == nil)
    #expect(h.model.missingProjects.isEmpty)
  }

  /// A worktree removed in a terminal rather than in the app: paths are ids,
  /// so a badge and a commit date left behind would come back to whatever is
  /// created at that path next, saying a branch has landed when it has not.
  @Test func aWorktreeRemovedOutsideTheAppTakesItsBadgeAndItsDateWithIt() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "gone", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "gone"))

    h.model.mergeStates[created.id] = .merged(.ancestor, into: "main")
    h.model.lastCommits[created.id] = Date(timeIntervalSince1970: 1000)

    _ = try await h.git.run(
      ["worktree", "remove", "--force", created.path.path], in: h.project.path)
    await h.model.refresh(h.project)

    #expect(h.worktree(onBranch: "gone") == nil, "git no longer lists it")
    #expect(h.model.mergeStates[created.id] == nil)
    #expect(h.model.lastCommits[created.id] == nil)
    #expect(h.model.mergeChecks[created.id] == nil)
  }

  /// The dimming is per project and the alert is raised on the first failure
  /// only, so a project that leaves dimmed must not take the mark with it: it
  /// would come back to a project added under the same path and cost that one
  /// its alert.
  @Test func aProjectRemovedWhileDimmedTakesTheMarkWithIt() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let project = h.project
    try FileManager.default.removeItem(at: project.path.appendingPathComponent(".git"))
    await h.model.refresh(project)
    #expect(h.model.missingProjects == [project.id])

    h.model.presentedError = nil
    h.model.removeProject(project)

    #expect(h.model.missingProjects.isEmpty)

    await h.model.addProject(at: project.path)
    #expect(h.model.presentedError != nil, "still unreadable, and said so again")
  }

  @Test func aRepositoryGitCanNoLongerReadIsReportedOnceThenDimmed() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let project = h.project
    try FileManager.default.removeItem(at: project.path.appendingPathComponent(".git"))

    await h.model.refresh(project)
    let first = try #require(h.model.presentedError)
    #expect(first.title.hasPrefix("git worktree list failed"))
    #expect(h.model.missingProjects == [project.id])

    h.model.presentedError = nil
    await h.model.refreshWorktreesIfRecordsChanged()
    await h.model.refresh(project)

    #expect(h.model.presentedError == nil, "the same failure on every tick is one alert, not many")
    #expect(h.model.workspace.projects.count == 1)
  }

  /// What the descriptor limit used to produce: git "succeeds" and lists
  /// nothing. The project must keep what it had and say something went wrong.
  @Test func aRefreshWhereGitListsNothingKeepsTheWorktreesAndTheirTabs() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let project = h.project
    h.model.select(h.worktree(onBranch: "main")!)
    #expect(h.model.liveTerminalCount == 1)

    let muted = try h.modelOnFakeGit("exit 0")

    await muted.refresh(project)

    #expect(muted.workspace.worktrees(of: project.id).count == 1, "nothing was dropped")
    #expect(muted.workspace.tabs.count == 1)
    #expect(muted.presentedError != nil)
    #expect(muted.missingProjects == [project.id])
  }

  /// The watched directories also hold each worktree's `index`, which every
  /// `git status` rewrites, so most ticks mean nothing. A tick must read the
  /// record files and spawn git only when they differ from the last refresh.
  @Test func aTickWithUnchangedRecordsSpawnsNoGitAndAChangedHEADDoes() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let repository = h.project.path.path
    let counting = try h.modelOnFakeGit(
      """
      case "$1 $2" in
        "rev-parse --path-format=absolute") printf '%s/.git\\n' "\(repository)" ;;
        "worktree list") printf 'worktree %s\\nHEAD 1111111\\nbranch refs/heads/main\\n' "\(repository)" ;;
      esac
      """)
    func listings() -> Int { h.gitCalls().filter { $0.hasPrefix("worktree list") }.count }

    await counting.refreshWorktreesIfRecordsChanged()
    #expect(listings() == 1, "no records yet, so a full refresh")

    await counting.refreshWorktreesIfRecordsChanged()
    await counting.refreshWorktreesIfRecordsChanged()
    #expect(listings() == 1, "nothing changed, so nothing was spawned")
    #expect(
      h.gitCalls().filter { $0.hasPrefix("rev-parse") }.count == 1, "the common dir is cached")

    _ = try await h.git.run(["checkout", "-q", "-b", "moved"], in: h.project.path)
    await counting.refreshWorktreesIfRecordsChanged()
    #expect(listings() == 2, "HEAD changed, so git was asked again")
  }

  @Test func anExplicitRefreshReportsAFailureAlreadyShown() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let project = h.project
    try FileManager.default.removeItem(at: project.path.appendingPathComponent(".git"))
    await h.model.refresh(project)
    #expect(h.model.presentedError != nil)
    h.model.presentedError = nil
    await h.model.refresh(project)
    #expect(h.model.presentedError == nil, "a tick stays quiet")

    await h.model.refreshRequested(project)

    #expect(h.model.presentedError != nil, "the user asked, so the answer is shown again")
    #expect(h.model.missingProjects == [project.id])
  }

  /// A status read can fail for a moment: a lock, a slow disk, a directory
  /// mid-rename. The badge must not blink off for five seconds each time.
  @Test func aFailedStatusReadKeepsTheLastBadgeUntilTheNextGoodOne() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let flaky = try h.modelOnFakeGit(
      """
      while [ "${1#--}" != "$1" ]; do shift; done
      case "$1" in
        status) if [ -e "$SCRATCH/fail" ]; then exit 128; fi
                printf '## main\\n M a.txt\\n' ;;
      esac
      """)
    let main = try #require(h.worktree(onBranch: "main"))

    await flaky.refreshStatuses()
    #expect(flaky.statuses[main.id]?.changedFiles == 1)

    try Data().write(to: h.root.appendingPathComponent("fail"))
    await flaky.refreshStatuses()
    #expect(flaky.statuses[main.id]?.changedFiles == 1, "kept through the failed read")

    h.store.replaceWorktrees([], forProject: h.project.id)
    await flaky.refreshStatuses()
    #expect(flaky.statuses.isEmpty, "a worktree that is gone loses its badge")
  }

  /// Identity is the path, so a worktree made where one was removed takes
  /// its id, and with it whatever badge and removal warning were left over.
  @Test func aWorktreeRemadeAtTheSamePathDoesNotInheritTheOldOnesBadge() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let path = h.root.appendingPathComponent("demo-feature", isDirectory: true)
    _ = try await h.git.run(
      ["worktree", "add", "-b", "feature", path.path], in: h.project.path)
    await h.model.refresh(h.project)
    let feature = try #require(h.worktree(onBranch: "feature"))
    try "work\n".write(
      to: path.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
    await h.model.refreshStatuses()
    #expect(h.model.statuses[feature.id]?.changedFiles == 1)

    _ = try await h.git.run(["worktree", "remove", "--force", path.path], in: h.project.path)
    await h.model.refresh(h.project)

    #expect(h.model.statuses[feature.id] == nil, "the reading went with the worktree")
  }

  /// The reads run while the app carries on, so a worktree can be removed
  /// between asking git and hearing back. What comes back about it is a
  /// reading of something that has no row any more.
  @Test func aWorktreeRemovedWhileGitRanGetsNoBadgeFromThatRound() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let path = h.root.appendingPathComponent("demo-gone", isDirectory: true)
    _ = try await h.git.run(["worktree", "add", "-b", "gone", path.path], in: h.project.path)
    await h.model.refresh(h.project)
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

  @Test func aProjectWhoseDirectoryVanishesIsDimmedNotDropped() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let project = h.project
    h.model.select(h.worktree(onBranch: "main")!)
    try FileManager.default.removeItem(at: project.path)

    await h.model.refresh(project)

    #expect(h.model.workspace.projects.count == 1, "an unmounted drive must not delete the setup")
    #expect(h.model.missingProjects == [project.id])
    #expect(h.model.workspace.worktrees(of: project.id).count == 1, "kept as last seen")
  }

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

  /// A removal's stages run on a worktree that already earned its badge, and
  /// the count is real until the directory goes. Only a create claims a path
  /// whose last checkout left a reading worth nothing.
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
    h.model.creatingWorktreeClaims[main.id] = 1

    await h.model.refreshStatuses()
    #expect(h.model.statuses[main.id] == nil, "and the last checkout at this path leaves nothing")

    await h.model.refreshStatus(of: main.id)
    #expect(h.model.statuses[main.id] == nil, "a prompt's refresh reads no earlier")
  }

  /// The plain create, no file lists and no hook: nothing but the `defer`
  /// lets go of the path, and a row never let go of is never badged again.
  @Test func aCreateWithNoStagesAfterItLetsGoOfTheRow() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }

    await h.model.createWorktree(branch: "plain", basedOn: nil, createBranch: true, in: h.project)

    let created = try #require(h.worktree(onBranch: "plain"))
    #expect(h.model.creatingWorktreeClaims.isEmpty)
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

    let first = Task {
      await h.model.createWorktree(branch: "one", basedOn: nil, createBranch: true, in: h.project)
    }
    let second = Task {
      await h.model.createWorktree(branch: "two", basedOn: nil, createBranch: true, in: h.project)
    }
    for _ in 0..<250 where h.model.creatingWorktreeClaims.count < 2 {
      try await Task.sleep(for: .milliseconds(20))
    }
    let held = Set(h.model.creatingWorktreeClaims.keys)
    #expect(held.count == 2, "both, not just the later one")

    try Data().write(to: gate)
    await first.value
    await second.value

    #expect(h.model.creatingWorktreeClaims.isEmpty, "and each let go of its own")
    let one = try #require(h.worktree(onBranch: "one"))
    let two = try #require(h.worktree(onBranch: "two"))
    #expect(held == [one.id, two.id], "what was held is what git then listed")
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

    h.model.endConstruction(of: id, in: h.project)
    #expect(h.model.isUnderConstruction(id), "one still holds it")

    h.model.endConstruction(of: id, in: h.project)
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
    await h.model.worktreeSetups[created.id]?.value
    #expect(h.model.worktreeOperations.isEmpty, "the copy is done")

    for _ in 0..<100 where h.model.statuses[created.id] == nil {
      try await Task.sleep(for: .milliseconds(20))
    }

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
    for _ in 0..<200
    where !FileManager.default.fileExists(
      atPath: created.path.appendingPathComponent("build/two").path)
    {
      try await Task.sleep(for: .milliseconds(20))
    }

    await h.model.refreshStatuses()
    #expect(h.model.statuses[created.id] == nil, "nothing while the hook writes")

    try Data().write(to: gate)
    await h.model.worktreeSetups[created.id]?.value
    await h.model.refreshStatuses()

    #expect(h.model.statuses[created.id]?.changedFiles == 1, "the one untracked directory, after")
  }
}
