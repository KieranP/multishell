import Foundation
import MultishellCore
import TestScratch
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
    await harness.model.createWorktree(
      branch: "killed",
      basedOn: nil,
      createsBranch: true,
      in: harness.project,
    )
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
}
