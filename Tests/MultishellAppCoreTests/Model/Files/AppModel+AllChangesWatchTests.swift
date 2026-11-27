import Foundation
import MultishellCore
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite(.serialized) @MainActor
struct AppModelAllChangesWatchTests {
  @Test func aFileChangedWhileAReadRunsIsMarkedStaleThoughThatReadIsReadingIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, feature) = try await harness.openAllChangesTabOnFeature()
    let file = feature.path.appending(path: "a.txt")
    try "a\n".write(to: file, atomically: true, encoding: .utf8)
    await harness.model.refreshStatuses()
    try await waitUntil { harness.allChangesPaths(in: tab)?.count == 1 }
    harness.model.noteAllChangesFilesNear(["a.txt"], in: tab.id)
    try await waitUntil {
      harness.model.allChangesReadings[tab.id]?.files.allSatisfy { $0.rows != nil } == true
    }
    try await waitUntil { harness.model.pendingAllChangesReads.isEmpty }
    harness.model.allChangesStaleFiles.mark(.everything, in: tab.id)
    let read = Task { await harness.model.readAllChangesTab(tab.id) }
    while !harness.model.allChangesReadLog.isReading(tab.id) { await Task.yield() }
    let common = try #require(
      try await harness.model.coordinator?.git.commonGitDirectory(harness.project)
    )

    harness.model.noteAllChangesTabChanges(
      FileChangeTargets(
        changed: [file],
        projects: [harness.project],
        gitDirectories: [harness.project.id: common],
        worktrees: harness.model.workspace.worktrees,
        themesDirectory: harness.model.themesDirectory,
      )
    )

    #expect(harness.model.allChangesStaleFiles.pending(tab.id).contains("a.txt"))
    await read.value
  }
}
