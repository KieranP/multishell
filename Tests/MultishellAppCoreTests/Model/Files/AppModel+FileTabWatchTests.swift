import Foundation
import MultishellCore
import MultishellGitKit
import TestScratch
import Testing

@testable import MultishellAppCore

@Suite(.serialized) @MainActor
struct AppModelFileTabWatchTests {
  @Test func aTabInAnEmbeddedRepositoryIsOwedAReadWhenThatRepositoryCommits() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    let folder = main.path.appending(path: "vendor/lib")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try "notes\n".write(to: folder.appending(path: "notes.txt"), atomically: true, encoding: .utf8)
    let (tab, _) = try harness.openFileTab("vendor/lib/notes.txt")
    try await waitUntil { harness.model.fileTabReadings[tab.id] != nil }
    harness.model.newShellTab()
    try #require(!harness.model.fileTabReadLog.owed.contains(tab.id))
    let common = try #require(
      try await harness.model.coordinator?.git.commonGitDirectory(harness.project)
    )
    let targets = FileChangeTargets(
      changed: [main.path.appending(path: "vendor/lib/.git/index")],
      projects: [harness.project],
      gitDirectories: [harness.project.id: common],
      worktrees: harness.model.workspace.worktrees,
      themesDirectory: harness.model.themesDirectory,
    )

    harness.model.noteFileTabChanges(targets)

    #expect(harness.model.fileTabReadLog.owed.contains(tab.id))
  }
}
