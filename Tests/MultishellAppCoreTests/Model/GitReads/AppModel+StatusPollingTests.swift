import Foundation
import MultishellCore
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite(.serialized) @MainActor
struct AppModelStatusPollingTests {
  @Test func theStatusPollSkipsTheWorktreesOfAMissingProject() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let fake = try h.modelOnFakeGit("exit 0")
    let project = fake.workspace.projects[0]

    fake.missingProjects.insert(project.id)
    await fake.refreshStatuses()
    #expect(!h.gitCalls().contains { $0.contains("status") }, "its directory is gone")

    fake.missingProjects.remove(project.id)
    await fake.refreshStatuses()
    #expect(h.gitCalls().contains { $0.contains("status") })
  }

  @Test func aWorktreeWhoseStatusIsSlowIsNotAskedAgainOnTheNextTick() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let fake = try h.modelOnFakeGit("case \"$*\" in *status*) sleep 0.6;; esac; exit 0")
    fake.statusReads.pace = .standard

    await fake.refreshStatuses()
    await fake.refreshStatuses()

    #expect(
      h.gitCalls().filter { $0.contains("status") }.count == 1,
      "a read that took 0.6 s is not due again for 6 s")
  }

  @Test func changingTheGitStatusIndicatorReadsEveryBadgeAtOnce() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    h.model.statusReads.pace = .standard

    await h.model.refreshStatuses()
    #expect(!h.model.statusReads.isEmpty, "a read the pace would hold the next one back for")

    h.model.setGitStatusIndicator(.stagedOnly)
    #expect(h.model.statusReads.isEmpty, "nothing left to pace the next read against")

    try await waitUntil { !h.model.statusReads.isEmpty }
    #expect(!h.model.statusReads.isEmpty, "and the read it asked for has landed")
    #expect(h.model.workspace.gitStatusIndicator == .stagedOnly)
  }
  /// A prompt's refresh is unpaced no more than the poll is: before this it
  /// ran on every burst of terminal output, three git calls a time.
  @Test func aPromptsRefreshOfASlowWorktreeWaitsForThePaceToo() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let fake = try h.modelOnFakeGit("case \"$*\" in *status*) sleep 0.6;; esac; exit 0")
    fake.statusReads.pace = .standard
    let worktree = try #require(fake.workspace.worktrees.first)

    await fake.refreshStatuses()
    await fake.refreshStatus(of: worktree.id)

    #expect(
      h.gitCalls().filter { $0.contains("status") }.count == 1,
      "a read that took 0.6 s is not due again for 6 s, whoever asks")
  }
  /// Landing last, the read in flight would put the old setting's counts
  /// back. The fake git sleeps in the diff it uses so that it does land last.
  @Test func aReadStartedBeforeTheIndicatorChangedBadgesNothing() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let fake = try h.modelOnFakeGit(
      """
      case "$*" in
        *status*) printf '## main\\n M README.md\\n';;
        *--cached*) ;;
        *numstat*) sleep 0.5; printf '3\\t0\\tREADME.md\\n';;
      esac
      exit 0
      """)
    let main = try #require(fake.workspace.worktrees.first)

    let stale = Task { await fake.refreshStatus(of: main.id) }
    await Task.yield()
    fake.setGitStatusIndicator(.stagedOnly)
    await stale.value

    try await waitUntil { fake.statuses[main.id] != nil }
    #expect(
      fake.statuses[main.id]?.insertions == 0,
      "the staged-only read, not the staged-and-unstaged one that was already running")
  }
  /// A removal or a stage starting mid-read threw the answer away and left
  /// the badge stale for ten times what that read cost.
  @Test func aReadDiscardedForARowUnderConstructionPacesNothing() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let fake = try h.modelOnFakeGit("case \"$*\" in *status*) sleep 0.6;; esac; exit 0")
    fake.statusReads.pace = .standard
    let main = try #require(fake.workspace.worktrees.first)

    let discarded = Task { await fake.refreshStatus(of: main.id) }
    await Task.yield()
    fake.pathClaims.claim(main.id)
    await discarded.value
    fake.pathClaims.release(main.id)
    await fake.refreshStatus(of: main.id)

    #expect(
      h.gitCalls().filter { $0.contains("status") }.count == 2,
      "the second read is due, the first having badged nothing")
  }

  @Test func openingAProjectRereadsNoRowThePollIsStillReading() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let gate = h.root.appendingPathComponent("go")
    let fake = try h.modelOnFakeGit(
      """
      case "$*" in
        *status*)
          if [ ! -f "$SCRATCH/first" ]; then
            touch "$SCRATCH/first"
            while [ ! -f "\(gate.path)" ]; do sleep 0.02; done
          fi
          printf '## main\\n' ;;
      esac
      """)

    let poll = Task { await fake.refreshStatuses() }
    try await waitUntil { h.statusRunCount() > 0 }
    await fake.refreshStatuses(inProject: h.project.id)
    try Data().write(to: gate)
    await poll.value

    #expect(h.statusRunCount() == 1)
  }

  @Test func aPromptsRefreshWhileThePollReadsItsRowIsReadOnceThePollLands() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let gate = h.root.appendingPathComponent("go")
    let fake = try h.modelOnFakeGit(
      """
      case "$*" in
        *status*)
          if [ ! -f "$SCRATCH/first" ]; then
            touch "$SCRATCH/first"
            while [ ! -f "\(gate.path)" ]; do sleep 0.02; done
          fi
          printf '## main\\n' ;;
      esac
      """)
    let main = try #require(fake.workspace.worktrees(of: h.project.id).first)
    fake.statusPolling?.cancel()

    let poll = Task { await fake.refreshStatuses() }
    try await waitUntil { h.statusRunCount() > 0 }
    await fake.refreshStatus(of: main.id)
    try Data().write(to: gate)
    await poll.value

    try await waitUntil { h.statusRunCount() == 2 }
    #expect(h.statusRunCount() == 2, "the refresh asked for mid-read was dropped")
  }

  @Test func aTickNamingOneProjectsRecordsLeavesTheOtherProjectUnread() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let second = h.root.appendingPathComponent("other", isDirectory: true)
    try await TestRepository.initialise(at: second, using: h.git)
    try await TestRepository.commitInitial(in: second, using: h.git)
    await h.model.addProject(at: second)
    let other = try #require(h.model.workspace.projects.first { $0.id != h.project.id })
    let common = try #require(await h.model.commonGitDirectory(of: h.project))
    _ = try await h.git.run(
      ["worktree", "add", "-b", "quiet", h.root.appendingPathComponent("quiet").path], in: second)
    h.watcher.watched = []

    await h.model.refreshWorktreesIfRecordsChanged(
      under: [common.appendingPathComponent("worktrees")])
    #expect(
      h.model.workspace.worktrees(of: other.id).count == 1, "the other's records were not read")
    #expect(h.watcher.watched.isEmpty, "nothing changed, so nothing was re-armed")

    await h.model.refreshWorktreesIfRecordsChanged()
    #expect(h.model.workspace.worktrees(of: other.id).count == 2)
    #expect(!h.watcher.watched.isEmpty)
  }
}
