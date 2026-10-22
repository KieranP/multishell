import Foundation
import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite(.serialized) @MainActor
struct AppModelWorktreeStatusRefreshTests {
  /// A single row's read is unpaced no more than a full read is: unpaced, each
  /// burst of file events would run it, three git calls a time.
  @Test func aSingleRowsReadOfASlowWorktreeWaitsForThePaceToo() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let fake = try harness.modelWithSlowStatus()
    let worktree = try #require(fake.workspace.worktrees.first)

    await fake.refreshStatuses()
    await fake.refreshStatus(of: worktree.id)

    #expect(
      harness.statusRunCount() == 1,
      "a read that took 0.6 s is not due again for 6 s, whoever asks",
    )
  }

  /// Landing last, the read in flight would put the old setting's counts
  /// back. The fake git sleeps in the diff it uses so that it does land last.
  @Test func aReadStartedBeforeTheIndicatorChangedBadgesNothing() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let fake = try harness.modelOnFakeGit(
      """
      case "$*" in
        *status*) printf '## main\\0 M README.md\\0';;
        *--cached*) ;;
        *numstat*) sleep 0.5; printf '3\\t0\\tREADME.md\\n';;
      esac
      exit 0
      """
    )
    let main = try #require(fake.workspace.worktrees.first)

    let stale = Task { await fake.refreshStatus(of: main.id) }
    await Task.yield()
    fake.setGitStatusIndicator(.stagedOnly)
    _ = await stale.value

    try await waitUntil { fake.statuses[main.id] != nil }
    #expect(
      fake.statuses[main.id]?.insertions == 0,
      "the staged-only read, not the staged-and-unstaged one that was already running",
    )
  }

  /// A removal or a stage starting mid-read threw the answer away and left
  /// the badge stale for ten times what that read cost.
  @Test func aReadDiscardedForARowUnderConstructionPacesNothing() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let fake = try harness.modelWithSlowStatus()
    let main = try #require(fake.workspace.worktrees.first)

    let discarded = Task { await fake.refreshStatus(of: main.id) }
    await Task.yield()
    fake.pathClaims.claim(main.id)
    _ = await discarded.value
    fake.pathClaims.release(main.id)
    await fake.refreshStatus(of: main.id)

    #expect(
      harness.statusRunCount() == 2,
      "the second read is due, the first having badged nothing",
    )
  }

  @Test func aSingleRowsReadAskedWhileThePollReadsItRunsOnceThePollLands() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let gate = harness.root.appendingPathComponent("go")
    let fake = try harness.modelWithFirstStatusHeld(until: gate)
    let main = try #require(fake.workspace.worktrees(of: harness.project.id).first)
    fake.statusPolling?.cancel()

    let poll = Task { await fake.refreshStatuses() }
    try await waitUntil { harness.statusRunCount() > 0 }
    await fake.refreshStatus(of: main.id)
    try Data().write(to: gate)
    await poll.value

    try await waitUntil { harness.statusRunCount() == 2 }
    #expect(harness.statusRunCount() == 2, "the refresh asked for mid-read was dropped")
  }

  @Test func aSingleRowsReadThatFindsANewBranchInTheMainWorktreeMovesItsRow() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    _ = try await harness.git.run(["checkout", "-q", "-b", "elsewhere"], in: harness.project.path)

    await harness.model.refreshStatus(of: main.id)

    #expect(harness.worktree(onBranch: "elsewhere") != nil)
    #expect(harness.worktree(onBranch: "main") == nil)
  }

  @Test func aSingleRowsReadAsksNothingOfAWorktreeInAMissingProject() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let model = try harness.modelOnFakeGit("")
    let main = try #require(harness.worktree(onBranch: "main"))
    model.missingProjects.insert(harness.project.id)

    await model.refreshStatus(of: main.id)

    #expect(harness.statusRunCount() == 0)
  }

  /// The forced read began before the change and lands while the queued one
  /// waits for the pace, moving the pace on under it.
  @Test func aQueuedReadIsStillMadeWhenAForcedReadLandsWhileItWaits() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let gate = harness.root.appendingPathComponent("go")
    try Data().write(to: gate)
    let fake = try harness.modelWithStatusHeld(until: gate, answering: "main")
    fake.statusReadLog.pace = StatusReadPace(minimumGap: .seconds(1), costMultiple: 0)
    let main = try #require(fake.workspace.worktrees.first)
    await fake.refreshStatus(of: main.id)
    try FileManager.default.removeItem(at: gate)

    let forced = Task { await fake.refreshStatus(of: main.id, forced: true) }
    try await waitUntil { harness.statusRunCount() == 2 }
    fake.scheduleStatusRefresh(of: main.id)
    try await Task.sleep(for: .milliseconds(450))
    try Data().write(to: gate)
    _ = await forced.value

    try await waitUntil { harness.statusRunCount() == 3 }
    #expect(harness.statusRunCount() == 3)
  }

  /// A single row's read is in flight when the worktree goes. Paths are
  /// ids, so its answer could badge a row re-made at the same path.
  @Test func aStatusThatArrivesAfterTheWorktreeWentBadgesNothing() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = harness.model.workspace.worktrees(of: harness.project.id)[0]
    try harness.dirty(main)
    harness.clearStatuses()

    let refresh = Task { await harness.model.refreshStatus(of: main.id) }
    // One turn: the refresh has asked git and is waiting on the answer.
    await Task.yield()
    harness.store.replaceWorktrees([], forProject: harness.project.id)
    _ = await refresh.value

    #expect(harness.model.statuses[main.id] == nil)
  }
}
