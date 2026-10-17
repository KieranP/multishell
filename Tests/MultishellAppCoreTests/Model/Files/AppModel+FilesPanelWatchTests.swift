import Foundation
import MultishellCore
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite(.serialized) @MainActor
struct AppModelFilesPanelWatchTests {
  @Test func aBatchWithGitAndFileChangesStillRereadsWhatGitIgnores() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    harness.model.setShowsFilesPanel(true)
    try await waitUntil { harness.model.pendingIgnoredEntriesReads[main.id] == nil }
    let gitDirectory = try #require(harness.model.commonGitDirectories[main.projectID])
    let targets = FileChangeTargets(
      changed: [gitDirectory.appending(path: "index"), main.path.appending(path: "build")],
      projects: harness.model.workspace.projects,
      gitDirectories: harness.model.commonGitDirectories,
      worktrees: harness.model.workspace.worktrees,
    )

    harness.model.noteFilesPanelChanges(targets)

    #expect(harness.model.pendingIgnoredEntriesReads[main.id] != nil)
  }

  @Test func aBatchNamingTheWholeWorktreeRereadsItsOpenIgnoredFolder() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    let leftPad = try await harness.openIgnoredFolder(in: main)
    try FileManager.default.removeItem(at: leftPad)
    let targets = FileChangeTargets(
      changed: [main.path],
      projects: harness.model.workspace.projects,
      gitDirectories: harness.model.commonGitDirectories,
      worktrees: harness.model.workspace.worktrees,
    )
    #expect(targets.fileChangesByWorktree[main.id] == [""])

    harness.model.noteFilesPanelChanges(targets)

    try await waitUntil { !harness.listsLeftPad(in: main) }
    #expect(!harness.listsLeftPad(in: main))
  }

  @Test func aLockFileDeletedInAReadIgnoredFolderRereadsTheFolder() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    let lock = main.path.appending(path: "node_modules/yarn.lock")
    try FileManager.default.createDirectory(
      at: lock.deletingLastPathComponent(),
      withIntermediateDirectories: true,
    )
    try "x\n".write(to: lock, atomically: true, encoding: .utf8)
    _ = try await harness.openIgnoredFolder(in: main)
    let lists = {
      harness.model.fileTreeRows(of: main.id).contains { $0.path == "node_modules/yarn.lock" }
    }
    #expect(lists())
    try FileManager.default.removeItem(at: lock)
    let targets = FileChangeTargets(
      changed: [lock],
      projects: harness.model.workspace.projects,
      gitDirectories: harness.model.commonGitDirectories,
      worktrees: harness.model.workspace.worktrees,
    )
    #expect(targets.fileChangesByWorktree[main.id] == ["node_modules/yarn.lock"])

    harness.model.noteFilesPanelChanges(targets)

    try await waitUntil { !lists() }
    #expect(!lists())
  }
}
