import Foundation
import MultishellCore
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore

@Suite(.serialized) @MainActor
struct AppModelIgnoredFilesTests {
  @Test func hidingIgnoredFilesTakesWhatGitIgnoresOutOfThePanel() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    _ = try await harness.ignoredFolderRow(in: main)

    harness.model.setShowsIgnoredFiles(false)

    #expect(!harness.model.fileTreeRows(of: main.id).contains { $0.isIgnored })
    #expect(!harness.model.fileTreeRows(of: main.id).contains { $0.path == "node_modules" })
  }

  @Test func aPanelWithIgnoredFilesHiddenNeverReadsWhatGitIgnores() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    try harness.writeIgnored("node_modules/left-pad/index.js", matching: "node_modules/", in: main)
    harness.model.setShowsIgnoredFiles(false)

    harness.model.select(main)
    harness.model.setShowsFilesPanel(true)
    try await waitUntil { harness.model.trackedFiles[main.id] != nil }

    #expect(!harness.model.ignoredEntriesReads.isRunning(main.id))
    #expect(harness.model.ignoredEntries[main.id] == nil)
  }

  @Test func showingIgnoredFilesAgainListsWhatGitIgnores() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    try harness.writeIgnored("node_modules/left-pad/index.js", matching: "node_modules/", in: main)
    harness.model.setShowsIgnoredFiles(false)
    harness.model.select(main)
    harness.model.setShowsFilesPanel(true)
    try await waitUntil { harness.model.trackedFiles[main.id] != nil }

    harness.model.setShowsIgnoredFiles(true)

    try await waitUntil {
      harness.model.fileTreeRows(of: main.id).contains { $0.path == "node_modules" && $0.isIgnored }
    }
    #expect(harness.model.fileTreeRows(of: main.id).contains { $0.path == "node_modules" })
  }

  @Test func showingIgnoredFilesAgainRereadsAnIgnoredFolderLeftOpen() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    let leftPad = try await harness.openIgnoredFolder(in: main)
    harness.model.setShowsIgnoredFiles(false)
    try await waitUntil { !harness.model.panelFolderReads.isRunning { _ in true } }
    try FileManager.default.removeItem(at: leftPad)

    harness.model.setShowsIgnoredFiles(true)

    try await waitUntil { !harness.listsLeftPad(in: main) }
    #expect(!harness.listsLeftPad(in: main))
  }

  @Test func hidingIgnoredFilesStopsTheirReadsUnderWay() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    _ = try await harness.openIgnoredFolder(in: main)
    try #require(harness.model.ignoredEntriesReads.isRunning(main.id))

    harness.model.setShowsIgnoredFiles(false)

    #expect(!harness.model.ignoredEntriesReads.isRunning(main.id))
    #expect(!harness.model.panelFolderReads.isRunning { $0.kind == .ignoredFolder })
  }
}
