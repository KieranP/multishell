import Foundation
import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite(.serialized) @MainActor
struct AppModelStatusReadsTests {
  @Test func theStatusPollSkipsTheWorktreesOfAMissingProject() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let fake = try harness.modelOnFakeGit("exit 0")
    let project = fake.workspace.projects[0]

    fake.missingProjects.insert(project.id)
    await fake.refreshStatuses()
    #expect(harness.statusRunCount() == 0, "its directory is gone")

    fake.missingProjects.remove(project.id)
    await fake.refreshStatuses()
    #expect(harness.statusRunCount() > 0)
  }

  @Test func aWorktreeWhoseStatusIsSlowIsNotAskedAgainOnTheNextTick() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let fake = try harness.modelWithSlowStatus()

    await fake.refreshStatuses()
    await fake.refreshStatuses()

    #expect(
      harness.statusRunCount() == 1,
      "a read that took 0.6 s is not due again for 6 s")
  }

  @Test func openingAProjectRereadsNoRowThePollIsStillReading() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let gate = harness.root.appendingPathComponent("go")
    let fake = try harness.modelWithFirstStatusHeld(until: gate)

    let poll = Task { await fake.refreshStatuses() }
    try await waitUntil { harness.statusRunCount() > 0 }
    await fake.refreshStatuses(inProject: harness.project.id)
    try Data().write(to: gate)
    await poll.value

    #expect(harness.statusRunCount() == 1)
  }

  @Test func aBranchSwitchInTheMainWorktreeIsCaughtByTheStatusPoll() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    _ = try await harness.git.run(["checkout", "-q", "-b", "elsewhere"], in: harness.project.path)
    #expect(harness.worktree(onBranch: "main") != nil, "nothing has looked yet")

    await harness.model.refreshStatuses()

    #expect(harness.worktree(onBranch: "elsewhere") != nil)
    #expect(harness.worktree(onBranch: "main") == nil)
    let statuses = harness.model.statuses
    #expect(statuses.count == 1 && statuses.values.first?.branch == "elsewhere")
  }

  /// A status read can fail for a moment: a lock, a slow disk, a directory
  /// mid-rename. The badge must not blink off for five seconds each time.
  @Test func aFailedStatusReadKeepsTheLastBadge() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let flaky = try harness.modelOnFakeGit(
      """
      while [ "${1#--}" != "$1" ]; do shift; done
      case "$1" in
        status) if [ -e "$SCRATCH/fail" ]; then exit 128; fi
                printf '## main\\n M a.txt\\n' ;;
      esac
      """)
    let main = try #require(harness.worktree(onBranch: "main"))

    await flaky.refreshStatuses()
    #expect(flaky.statuses[main.id]?.changedFiles == 1)

    try Data().write(to: harness.root.appendingPathComponent("fail"))
    await flaky.refreshStatuses()
    #expect(flaky.statuses[main.id]?.changedFiles == 1, "kept through the failed read")
  }

  @Test func aWorktreeThatIsGoneLosesItsBadge() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let model = try harness.modelOnFakeGit(
      """
      while [ "${1#--}" != "$1" ]; do shift; done
      case "$1" in status) printf '## main\\n M a.txt\\n' ;; esac
      """)
    let main = try #require(harness.worktree(onBranch: "main"))
    await model.refreshStatuses()
    #expect(model.statuses[main.id] != nil)

    harness.store.replaceWorktrees([], forProject: harness.project.id)
    await model.refreshStatuses()

    #expect(model.statuses.isEmpty)
  }

  @Test func changingTheGitStatusIndicatorReadsEveryBadgeAtOnce() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.statusReadLog.pace = .standard

    await harness.model.refreshStatuses()
    #expect(
      !harness.model.statusReadLog.hasNoReadings, "a read the pace would hold the next one back for"
    )

    harness.model.setGitStatusIndicator(.stagedOnly)
    #expect(harness.model.statusReadLog.hasNoReadings, "nothing left to pace the next read against")

    try await waitUntil { !harness.model.statusReadLog.hasNoReadings }
    #expect(!harness.model.statusReadLog.hasNoReadings, "and the read it asked for has landed")
    #expect(harness.model.workspace.gitStatusIndicator == .stagedOnly)
  }

  /// The reads run while the app carries on, so a worktree can be removed
  /// between asking git and hearing back.
  @Test func aWorktreeRemovedWhileGitRanGetsNoBadgeFromThatRound() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let path = harness.root.appendingPathComponent("demo-gone", isDirectory: true)
    try await harness.addOutsideTheApp("gone", at: path)
    await harness.model.refreshWorktrees(of: harness.project)
    let doomed = try #require(harness.worktree(onBranch: "gone"))
    let main = try #require(harness.worktree(onBranch: "main"))
    // A git slow enough that the removal lands while the round is inside it.
    let slow = try harness.modelOnFakeGit(
      """
      while [ "${1#--}" != "$1" ]; do shift; done
      case "$1" in
        status) sleep 1; printf '## main\\n M a.txt\\n' ;;
      esac
      """)

    let round = Task { await slow.refreshStatuses() }
    try await waitUntil { harness.statusRunCount() > 0 }
    harness.store.replaceWorktrees([main], forProject: harness.project.id)
    await round.value

    #expect(slow.statuses[main.id] != nil, "the round landed, so there is something to judge")
    #expect(slow.statuses[doomed.id] == nil, "a row that has gone keeps no reading")
  }
}
