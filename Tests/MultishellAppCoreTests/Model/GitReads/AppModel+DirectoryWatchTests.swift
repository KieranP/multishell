import Foundation
import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite(.serialized) @MainActor
struct AppModelDirectoryWatchTests {
  /// The first re-arm to ask whether a directory is local waits on the gate,
  /// so a second re-arm can overtake it.
  private func holdingTheFirstVolumeCheck(
    in harness: GitHarness
  ) -> (checks: Recorder<Int>, gate: DispatchSemaphore) {
    let checks = Recorder<Int>()
    let gate = DispatchSemaphore(value: 0)
    harness.model.isOnLocalVolume = { _ in
      checks.record(0)
      if checks.received.count == 1 { gate.wait() }
      return true
    }
    return (checks, gate)
  }

  @Test func aReArmThatLandsAfterANewerOneLeavesTheNewerDirectoriesWatched() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let common = try #require(harness.model.commonGitDirectories[harness.project.id])
    let (volumeChecks, gate) = holdingTheFirstVolumeCheck(in: harness)

    let older = Task { await harness.model.refreshWorktreesOnRequest(of: harness.project) }
    try await waitUntil { !volumeChecks.received.isEmpty }
    let added = harness.root.appending(path: "added", directoryHint: .isDirectory)
    try await harness.addOutsideTheApp("added", at: added)
    await harness.model.noteFileChanges([common.appending(path: "worktrees")])
    gate.signal()
    await older.value

    let worktree = try #require(harness.worktree(onBranch: "added"))
    #expect(harness.watcher.watched.contains(worktree.path))
  }

  @Test func aForcedReArmOvertakenByAnUnforcedOneLeavesTheListArmed() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (volumeChecks, gate) = holdingTheFirstVolumeCheck(in: harness)
    harness.watcher.watched = []

    let forced = Task { await harness.model.rearmWatcher(evenIfUnchanged: true) }
    try await waitUntil { !volumeChecks.received.isEmpty }
    await harness.model.rearmWatcher()
    gate.signal()
    await forced.value

    #expect(!harness.watchedRepositoryNames.isEmpty)
  }

  @Test func aForcedReArmOvertakenByOneWithNoProjectLeftLeavesOnlyTheThemesFolderWatched()
    async throws
  {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (volumeChecks, gate) = holdingTheFirstVolumeCheck(in: harness)

    let forced = Task { await harness.model.rearmWatcher(evenIfUnchanged: true) }
    try await waitUntil { !volumeChecks.received.isEmpty }
    let callsBeforeRemoval = harness.watcher.calls.count
    harness.model.removeProject(harness.project)
    await harness.model.rearmWatcher()
    gate.signal()
    await forced.value
    let themesAlone = [harness.model.themesDirectory]
    try await waitUntil { harness.watcher.watched == themesAlone }

    #expect(harness.watcher.calls.dropFirst(callsBeforeRemoval).allSatisfy { $0 == themesAlone })
  }
}
