import Foundation
import MultishellCore
import MultishellProcess
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

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

  /// A prompt's status refresh is in flight when the worktree goes. Paths are
  /// ids, so its answer could badge a row re-made at the same path.
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

  /// The same with git failing: the failure lands on a project that has
  /// gone, and must neither dim a stale id nor alert about it.
  @Test func aFailingRefreshLandingAfterTheProjectWasRemovedLeavesNoTrace() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let project = h.project
    let failing = try h.modelOnFakeGit(
      """
      case "$1 $2" in
        "worktree list") while [ ! -e "$SCRATCH/go" ]; do sleep 0.02; done; exit 128 ;;
      esac
      """)

    let refresh = Task { await failing.refresh(project) }
    try await waitUntil { h.gitCalls().contains { $0.hasPrefix("worktree list") } }
    failing.removeProject(project)
    try "".write(to: h.root.appendingPathComponent("go"), atomically: true, encoding: .utf8)
    await refresh.value

    #expect(failing.missingProjects.isEmpty)
    #expect(failing.presentedError == nil)
  }

  /// Paths are ids, so a leftover badge and commit date would pass to the next
  /// worktree at that path, saying a branch has landed when it has not.
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

  /// The alert fires on a project's first failure only, so a dimmed mark left
  /// behind would cost a project later added under the same path its alert.
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
  /// `git status` rewrites, so most ticks mean nothing.
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
  /// between asking git and hearing back.
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
    h.model.workInFlight.claim(main.id)

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

  @Test func aCollapsedProjectsWorktreesAreNotReadUntilItOpens() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "side", basedOn: nil, createBranch: true, in: h.project)
    let side = try #require(h.worktree(onBranch: "side"))
    let main = try #require(h.worktree(onBranch: "main"))
    h.model.select(main)
    for worktree in [side, main] {
      try "x".write(
        to: worktree.path.appendingPathComponent("dirty.txt"), atomically: true, encoding: .utf8)
    }
    for pending in h.model.pendingStatusRefreshes.values { pending.cancel() }
    h.model.pendingStatusRefreshes = [:]
    h.model.statuses = [:]

    h.model.setExpanded(false, for: h.project)
    await h.model.refreshStatuses()
    #expect(h.model.statuses[side.id] == nil)
    #expect(h.model.statuses[main.id]?.changedFiles == 1, "the main one, for its branch")

    h.model.setExpanded(true, for: h.project)
    #expect(h.model.pendingStatusRefreshes.isEmpty, "one capped poll, not a read per row")
    try await waitUntil { h.model.statuses[side.id] != nil }
    #expect(h.model.statuses[side.id]?.changedFiles == 1)
  }

  @Test func openingOneProjectReadsNoOtherProjectsWorktrees() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let other = h.root.appendingPathComponent("other", isDirectory: true)
    try await TestRepository.initialise(at: other, using: h.git)
    try await TestRepository.commitInitial(in: other, using: h.git)
    await h.model.addProject(at: other)
    let otherProject = try #require(h.model.workspace.projects.first { $0.id != h.project.id })
    let otherMain = try #require(h.model.workspace.worktrees(of: otherProject.id).first)
    await h.model.createWorktree(branch: "side", basedOn: nil, createBranch: true, in: h.project)
    let side = try #require(h.worktree(onBranch: "side"))
    h.model.select(try #require(h.worktree(onBranch: "main")))
    try "x".write(
      to: side.path.appendingPathComponent("dirty.txt"), atomically: true, encoding: .utf8)
    h.model.setExpanded(false, for: h.project)
    for pending in h.model.pendingStatusRefreshes.values { pending.cancel() }
    h.model.pendingStatusRefreshes = [:]
    var unread = WorktreeStatus()
    unread.branch = "main"
    unread.changedFiles = 99
    h.model.statuses = [otherMain.id: unread]

    h.model.setExpanded(true, for: h.project)

    try await waitUntil { h.model.statuses[side.id] != nil }
    #expect(h.model.statuses[otherMain.id] == unread)
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

  @Test func aWorktreeThatGoesTakesItsUntrackedLineCountsWithIt() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    h.model.setGitStatusIndicator(.stagedAndUnstaged)
    await h.model.createWorktree(branch: "side", basedOn: nil, createBranch: true, in: h.project)
    let side = try #require(h.worktree(onBranch: "side"))
    try "a\nb\n".write(
      to: side.path.appendingPathComponent("new.txt"), atomically: true, encoding: .utf8)
    await h.model.refreshStatus(of: side.id, forced: true)
    let memo = try #require(h.model.worktrees).service.untrackedMemo
    #expect(!memo.entries(in: side.path).isEmpty)

    _ = try await h.git.run(
      ["worktree", "remove", "--force", side.path.path], in: h.project.path)
    await h.model.refresh(h.project)

    #expect(h.worktree(onBranch: "side") == nil)
    #expect(memo.entries(in: side.path).isEmpty)
  }

  @Test func theLoginEnvironmentsGitKeepsTheCountsAndTheMergeWidthLaunchHad() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let path = try #require(ProcessInfo.processInfo.environment["PATH"])
    h.model.captureLoginEnvironment = {
      LoginShellEnvironment(
        variables: ["PATH": path, "HOME": h.root.path],
        source: .loginShell(URL(fileURLWithPath: "/bin/zsh")))
    }
    let launched = try #require(h.model.worktrees).service

    await h.model.refreshLoginEnvironment()

    let rebuilt = try #require(h.model.worktrees).service
    #expect(rebuilt.untrackedMemo === launched.untrackedMemo)
    #expect(rebuilt.mergeSlots === launched.mergeSlots)
  }

  @Test func askingToRemoveAWorktreeReadsItsStatusFirst() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "side", basedOn: nil, createBranch: true, in: h.project)
    let side = try #require(h.worktree(onBranch: "side"))
    h.model.select(try #require(h.worktree(onBranch: "main")))
    h.model.setExpanded(false, for: h.project)
    try "x".write(
      to: side.path.appendingPathComponent("dirty.txt"), atomically: true, encoding: .utf8)
    for pending in h.model.pendingStatusRefreshes.values { pending.cancel() }
    h.model.pendingStatusRefreshes = [:]
    h.model.statuses = [:]

    h.model.requestRemoval(of: side)

    try await waitUntil { h.model.pendingRemoval != nil }
    #expect(h.model.statuses[side.id]?.changedFiles == 1, "read before the dialog is built")
  }

  @Test func aRemovalThatAsksNothingRequestedTwiceRunsOnce() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "side", basedOn: nil, createBranch: true, in: h.project)
    let side = try #require(h.worktree(onBranch: "side"))
    h.model.select(try #require(h.worktree(onBranch: "main")))
    h.model.setExpanded(false, for: h.project)
    let log = h.root.appendingPathComponent("pre-delete.log")
    h.model.updateSettings(
      ProjectSettings(preDeleteHook: "echo ran >> \(log.path)"), for: h.project)
    h.model.setConfirmsWorktreeRemoval(false)
    h.model.setDeletesBranchWithWorktree(true)

    h.model.requestRemoval(of: side)
    h.model.requestRemoval(of: side)

    try await waitUntil { h.worktree(onBranch: "side") == nil }
    await h.awaitOperationEnd(on: side.id)
    let runs = try String(contentsOf: log, encoding: .utf8)
    #expect(runs == "ran\n")
  }

  @Test func aSlowWorktreeIsStillReadBeforeItsRemovalDialog() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "side", basedOn: nil, createBranch: true, in: h.project)
    let side = try #require(h.worktree(onBranch: "side"))
    h.model.select(try #require(h.worktree(onBranch: "main")))
    h.model.setExpanded(false, for: h.project)
    try "x".write(
      to: side.path.appendingPathComponent("dirty.txt"), atomically: true, encoding: .utf8)
    for pending in h.model.pendingStatusRefreshes.values { pending.cancel() }
    h.model.pendingStatusRefreshes = [:]
    h.model.statuses = [:]
    h.model.statusReads.pace = .standard
    h.model.statusReads.remember([side.id: .seconds(10)])

    h.model.requestRemoval(of: side)

    try await waitUntil { h.model.pendingRemoval != nil }
    #expect(h.model.statuses[side.id]?.changedFiles == 1, "read before the dialog is built")
  }

  @Test func aRowOnScreenThePaceHoldsBackIsStillReadBeforeItsRemovalDialog() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "side", basedOn: nil, createBranch: true, in: h.project)
    let side = try #require(h.worktree(onBranch: "side"))
    h.model.select(try #require(h.worktree(onBranch: "main")))
    try "x".write(
      to: side.path.appendingPathComponent("dirty.txt"), atomically: true, encoding: .utf8)
    for pending in h.model.pendingStatusRefreshes.values { pending.cancel() }
    h.model.pendingStatusRefreshes = [:]
    h.model.statuses = [:]
    h.model.statusReads.pace = .standard
    h.model.statusReads.remember([side.id: .seconds(3)])

    await h.model.requestRemoval(of: side)?.value

    #expect(h.model.pendingRemoval != nil)
    #expect(h.model.statuses[side.id]?.changedFiles == 1, "read before the dialog is built")
  }

  @Test func aRemovalReadLandingLateLeavesTheDialogThatOpenedMeanwhile() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "gated", basedOn: nil, createBranch: true, in: h.project)
    await h.model.createWorktree(branch: "quick", basedOn: nil, createBranch: true, in: h.project)
    let gated = try #require(h.worktree(onBranch: "gated"))
    let quick = try #require(h.worktree(onBranch: "quick"))
    h.model.select(try #require(h.worktree(onBranch: "main")))
    h.model.setExpanded(false, for: h.project)
    let gate = h.root.appendingPathComponent("go")
    let fake = try h.modelOnFakeGit(
      """
      case "$PWD $*" in
        *gated*status*) while [ ! -f "\(gate.path)" ]; do sleep 0.02; done; printf '## gated\\n' ;;
        *quick*status*) printf '## quick\\n' ;;
      esac
      """)

    fake.requestRemoval(of: gated)
    try await waitUntil { h.gitCalls().contains { $0.contains("status") } }
    fake.requestRemoval(of: quick)
    try await waitUntil { fake.pendingRemoval != nil }
    #expect(fake.pendingRemoval?.worktree.id == quick.id)
    try Data().write(to: gate)
    try await waitUntil { fake.statuses[gated.id] != nil }
    #expect(fake.statuses[gated.id] != nil, "the late read landed")

    #expect(fake.pendingRemoval?.worktree.id == quick.id, "the dialog up is the one confirmed")
  }

  @Test func aRemovalAskedTwiceWhileItsStatusIsReadReadsItOnce() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "gated", basedOn: nil, createBranch: true, in: h.project)
    let gated = try #require(h.worktree(onBranch: "gated"))
    h.model.select(try #require(h.worktree(onBranch: "main")))
    h.model.setExpanded(false, for: h.project)
    let gate = h.root.appendingPathComponent("go")
    let fake = try h.modelOnFakeGit(
      """
      case "$*" in
        *status*) while [ ! -f "\(gate.path)" ]; do sleep 0.02; done; printf '## gated\\n' ;;
      esac
      """)
    func statusReads() -> Int { h.gitCalls().filter { $0.contains("status") }.count }

    fake.requestRemoval(of: gated)
    fake.requestRemoval(of: gated)
    try await waitUntil { statusReads() > 0 }
    try Data().write(to: gate)
    try await waitUntil { fake.pendingRemoval != nil }

    #expect(statusReads() == 1)
  }

  @Test func aPauseInTypingReadsOnlyTheRowsTheFilterBroughtBack() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    for branch in ["side", "other"] {
      let path = h.root.appendingPathComponent("demo-\(branch)", isDirectory: true)
      _ = try await h.git.run(
        ["worktree", "add", "-q", "-b", branch, path.path], in: h.project.path)
    }
    await h.model.refresh(h.project)
    let side = try #require(h.worktree(onBranch: "side"))
    let other = try #require(h.worktree(onBranch: "other"))
    h.model.select(try #require(h.worktree(onBranch: "main")))
    h.model.sidebarFilterText = "side"
    await h.model.pendingRevealedRowsRead?.task.value
    for worktree in [side, other] {
      try "x".write(
        to: worktree.path.appendingPathComponent("dirty.txt"), atomically: true, encoding: .utf8)
    }
    h.model.statuses = [:]

    h.model.sidebarFilterText = ""
    await h.model.pendingRevealedRowsRead?.task.value

    #expect(h.model.statuses[other.id]?.changedFiles == 1, "brought back, so read")
    #expect(h.model.statuses[side.id] == nil, "on screen all along, so left to the poll")
  }

  @Test func aCollapsedProjectsRowTheFilterShowsIsRead() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "side", basedOn: nil, createBranch: true, in: h.project)
    let side = try #require(h.worktree(onBranch: "side"))
    h.model.select(try #require(h.worktree(onBranch: "main")))
    try "x".write(
      to: side.path.appendingPathComponent("dirty.txt"), atomically: true, encoding: .utf8)
    for pending in h.model.pendingStatusRefreshes.values { pending.cancel() }
    h.model.pendingStatusRefreshes = [:]
    h.model.statuses = [:]
    h.model.setExpanded(false, for: h.project)

    h.model.sidebarFilterText = "side"
    await h.model.refreshStatuses()

    #expect(h.model.statuses[side.id]?.changedFiles == 1)
  }

  @Test func clearingTheFilterReadsTheRowsItBringsBack() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "side", basedOn: nil, createBranch: true, in: h.project)
    let side = try #require(h.worktree(onBranch: "side"))
    h.model.select(try #require(h.worktree(onBranch: "main")))
    h.model.sidebarFilterText = "nothing-by-this-name"
    try "x".write(
      to: side.path.appendingPathComponent("dirty.txt"), atomically: true, encoding: .utf8)
    for pending in h.model.pendingStatusRefreshes.values { pending.cancel() }
    h.model.pendingStatusRefreshes = [:]
    h.model.statuses = [:]

    h.model.sidebarFilterText = ""

    try await waitUntil { h.model.statuses[side.id] != nil }
    #expect(h.model.statuses[side.id]?.changedFiles == 1)
  }

  @Test func renamingARowOfACollapsedProjectReadsTheRowsItOpens() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "side", basedOn: nil, createBranch: true, in: h.project)
    let side = try #require(h.worktree(onBranch: "side"))
    h.model.select(try #require(h.worktree(onBranch: "main")))
    h.model.setExpanded(false, for: h.project)
    try "x".write(
      to: side.path.appendingPathComponent("dirty.txt"), atomically: true, encoding: .utf8)
    for pending in h.model.pendingStatusRefreshes.values { pending.cancel() }
    h.model.pendingStatusRefreshes = [:]
    h.model.statuses = [:]

    h.model.beginRenaming(side)

    try await waitUntil { h.model.statuses[side.id] != nil }
    #expect(h.model.statuses[side.id]?.changedFiles == 1)
  }

  @Test func anExpandedProjectsRowTheFilterHidesIsNotRead() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "side", basedOn: nil, createBranch: true, in: h.project)
    let side = try #require(h.worktree(onBranch: "side"))
    h.model.select(try #require(h.worktree(onBranch: "main")))
    for pending in h.model.pendingStatusRefreshes.values { pending.cancel() }
    h.model.pendingStatusRefreshes = [:]
    h.model.statuses = [:]

    h.model.sidebarFilterText = "nothing-by-this-name"
    await h.model.refreshStatuses()

    #expect(h.model.statuses[side.id] == nil)
  }

  @Test func aPanesReadAsksNothingOfAWorktreeInAMissingProject() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let model = try h.modelOnFakeGit("")
    let main = try #require(h.worktree(onBranch: "main"))
    model.missingProjects.insert(h.project.id)

    await model.refreshStatus(of: main.id)

    #expect(!h.gitCalls().contains { $0.contains("status") })
  }

  @Test func aPollLandingAfterARemovalBeganIsDropped() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let gate = h.root.appendingPathComponent("go")
    let model = try h.modelOnFakeGit(
      """
      case "$*" in
        *status*) while [ ! -f "\(gate.path)" ]; do sleep 0.02; done
          printf '# branch.head main\\n1 .M N... 100644 100644 100644 a a x.txt\\n' ;;
      esac
      """)
    let main = try #require(h.worktree(onBranch: "main"))

    let poll = Task { await model.refreshStatuses() }
    try await waitUntil { h.gitCalls().contains { $0.contains("status") } }
    model.worktreeOperations.begin(.preDeleteHook, on: main.id)
    try Data().write(to: gate)
    await poll.value

    #expect(model.statuses[main.id] == nil)
  }

  /// The plain create, no file lists and no hook: nothing but the `defer`
  /// lets go of the path, and a row never let go of is never badged again.
  @Test func aCreateWithNoStagesAfterItLetsGoOfTheRow() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }

    await h.model.createWorktree(branch: "plain", basedOn: nil, createBranch: true, in: h.project)

    let created = try #require(h.worktree(onBranch: "plain"))
    #expect(!h.model.workInFlight.isClaimed(created.id))
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
    let work = { h.model.workInFlight }
    for _ in 0..<250 where !(work().isClaimed(plannedOne) && work().isClaimed(plannedTwo)) {
      try await Task.sleep(for: .milliseconds(20))
    }
    #expect(work().isClaimed(plannedOne) && work().isClaimed(plannedTwo), "both, not the later")

    try Data().write(to: gate)
    await first.value
    await second.value

    #expect(!work().isClaimed(plannedOne) && !work().isClaimed(plannedTwo), "each let go")
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
    await h.model.workInFlight.setup(of: created.id)?.value
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
    await h.model.workInFlight.setup(of: created.id)?.value
    await h.model.refreshStatuses()

    #expect(h.model.statuses[created.id]?.changedFiles == 1, "the one untracked directory, after")
  }
}
