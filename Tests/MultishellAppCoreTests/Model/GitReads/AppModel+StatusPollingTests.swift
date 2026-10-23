import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite(.serialized) @MainActor
struct AppModelStatusPollingTests {
  /// Only the lock's age tells a dead add from a running one, and time passing
  /// changes nothing in the records a watcher tick compares.
  @Test func aCreateKilledMidCheckoutGetsItsBadgeBackOnceItsLockIsOld() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    _ = try await harness.createWorktree(onBranch: "killed")
    let lock = harness.project.path.appendingPathComponent(".git/worktrees/killed/locked")
    try "initializing".write(to: lock, atomically: true, encoding: .utf8)
    await harness.model.refreshWorktrees(of: harness.project)
    let killed = try #require(harness.worktree(onBranch: "killed"))
    #expect(killed.isInitializing)
    try FileManager.default.setAttributes(
      [.modificationDate: Date(timeIntervalSinceNow: -3600)],
      ofItemAtPath: lock.path,
    )

    await harness.model.refreshProjectsIfChanged()
    await harness.model.pollRound()

    #expect(harness.worktree(onBranch: "killed")?.isInitializing == false)
    #expect(harness.model.statuses[killed.id] != nil)
  }

  /// File events miss what another machine writes to a share, so such a
  /// worktree is read on a short poll as well.
  @Test func aWorktreeOnANetworkVolumeIsPolledAndOneOnALocalVolumeIsNot() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let side = try await harness.createWorktree(onBranch: "side")
    let main = try #require(harness.worktree(onBranch: "main"))
    let sidePath = side.path.standardizedFileURL
    harness.model.isOnLocalVolume = { $0.standardizedFileURL != sidePath }
    await harness.model.rearmWatcher(evenIfUnchanged: true)
    for worktree in [side, main] { try harness.dirty(worktree) }
    harness.clearStatuses()

    await harness.model.pollWorktreesOnNetworkVolumes()

    #expect(harness.model.worktreesOnNetworkVolumes == [side.id])
    #expect(harness.model.statuses[side.id]?.changedFiles == 1)
    #expect(harness.model.statuses[main.id] == nil)
  }

  /// The round comes once a minute, so re-asks its budget left over would
  /// take thirty branches a quarter of an hour after a fetch.
  @Test func reAsksARoundLeftOverRunOnTheTicksBetweenRounds() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    var worktrees: [Worktree] = []
    for name in ["one", "two", "three"] {
      let worktree = try await harness.createWorktree(onBranch: name)
      _ = try await harness.git.run(
        ["commit", "-q", "--allow-empty", "-m", name],
        in: worktree.path,
      )
      worktrees.append(worktree)
    }
    await harness.model.refreshBranchScans()
    _ = try await harness.git.run(
      ["commit", "-q", "--allow-empty", "-m", "base"],
      in: harness.project.path,
    )
    let baseTip = try await harness.git.run(["rev-parse", "main"], in: harness.project.path)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    harness.model.mergeReadLog.budget = .zero
    func askedAgainstTheNewBase() -> Int {
      worktrees.count { harness.model.mergeVerdictBases[$0.id]?.defaultBranchTip == baseTip }
    }

    await harness.model.refreshBranchScans()
    #expect(askedAgainstTheNewBase() == 1, "the budget admits one")

    await harness.model.pollBetweenRounds()

    #expect(askedAgainstTheNewBase() == 2)
  }

  /// FSEvents reports nothing another machine writes to a share, so a worktree
  /// added there is listed by the round's own look at git's records.
  @Test func aWorktreeAddedWhereNoEventSaysSoIsListedByTheRound() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let added = harness.root.appending(path: "added", directoryHint: .isDirectory)
    try await harness.addOutsideTheApp("added", at: added)

    await harness.model.pollRound()

    #expect(harness.worktree(onBranch: "added") != nil)
  }
}
