import Foundation
import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit
@testable import MultishellProcess

@Suite(.serialized) @MainActor
struct AppModelRefreshTests {
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

    await h.model.refreshOnRequest(project)

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

  @Test func aWorktreeThatGoesTakesItsUntrackedLineCountsWithIt() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    h.model.setGitStatusIndicator(.stagedAndUnstaged)
    await h.model.createWorktree(branch: "side", basedOn: nil, createBranch: true, in: h.project)
    let side = try #require(h.worktree(onBranch: "side"))
    try "a\nb\n".write(
      to: side.path.appendingPathComponent("new.txt"), atomically: true, encoding: .utf8)
    await h.model.refreshStatus(of: side.id, forced: true)
    let memo = try #require(h.model.coordinator).git.shared.untrackedMemo
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
    let launched = try #require(h.model.coordinator).git

    await h.model.refreshLoginEnvironment()

    let rebuilt = try #require(h.model.coordinator).git
    #expect(rebuilt.shared.untrackedMemo === launched.shared.untrackedMemo)
    #expect(rebuilt.shared.mergeSlots === launched.shared.mergeSlots)
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
    await h.model.refresh(h.project)

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
    #expect(h.engine.openSessionIDs == sessions)

    _ = try await h.git.run(
      ["worktree", "remove", "--force", created.path.path], in: h.project.path)
    h.engine.focused.removeAll()
    await h.model.refresh(h.project)

    #expect(h.model.workspace.worktree(created.id) == nil)
    #expect(h.engine.openSessionIDs.isEmpty, "the shells outlived the row they belonged to")
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
    await h.model.refresh(h.project)
    #expect(h.worktree(onBranch: "setup") == nil, "git no longer lists it")
    await setup?.value

    #expect(h.model.worktreeOperations[created.id] == nil)
    #expect(h.model.stageHandles.setup(of: created.id) == nil)
    #expect(h.model.stageHandles.stopper(of: created.id) == nil)
    #expect(ContinuousClock.now - began < .seconds(12), "signalled, not waited out")
    #expect(h.model.presentedError == nil, "a worktree that is not there has nothing to report")
  }
}
