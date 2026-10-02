import Foundation
import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite(.serialized) @MainActor
struct AppModelStatusPollingTests {
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
  @Test func aFailedStatusReadKeepsTheLastBadgeUntilTheNextGoodOne() async throws {
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

    harness.store.replaceWorktrees([], forProject: harness.project.id)
    await flaky.refreshStatuses()
    #expect(flaky.statuses.isEmpty, "a worktree that is gone loses its badge")
  }
}
