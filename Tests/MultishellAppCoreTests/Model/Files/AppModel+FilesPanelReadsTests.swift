import Foundation
import MultishellCore
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite(.serialized) @MainActor
struct AppModelFilesPanelReadsTests {
  @Test func thePanelsWorktreeIsReadInTheBackgroundWhileItsWindowIsVisible() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    harness.model.setShowsFilesPanel(true)

    harness.platform.isActive = false
    #expect(harness.model.readsStatusInTheBackground(main.id))
    harness.platform.isWorkspaceWindowVisible = false
    #expect(!harness.model.readsStatusInTheBackground(main.id))
  }

  @Test func aServicesPageShownInTheBackgroundReadsNoStatus() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.connectServices()
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    harness.model.setShowsFilesPanel(true)
    harness.model.setFilesPanelMode(.ciRuns)
    harness.platform.isActive = false

    #expect(!harness.model.readsStatusInTheBackground(main.id))
  }

  @Test func thePanelIsReadWhenItsWindowBecomesVisibleInTheBackground() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    harness.model.setShowsFilesPanel(true)
    harness.platform.isActive = false
    harness.platform.isWorkspaceWindowVisible = false
    try harness.dirty(main)
    harness.clearStatuses()

    harness.platform.isWorkspaceWindowVisible = true
    harness.platform.onWorkspaceWindowDidBecomeVisible?()

    try await waitUntil { harness.model.statuses[main.id] != nil }
    #expect(harness.model.statuses[main.id]?.changedFiles == 1)
  }

  @Test func aWorktreeThePanelLeftOrClosedOnLetsGoOfItsListing() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    let other = try await harness.createWorktree(onBranch: "other")
    harness.model.select(main)
    harness.model.setShowsFilesPanel(true)
    harness.model.readFilesPanel(of: main.id)
    try await waitUntil { harness.model.trackedFiles[main.id] != nil }
    try #require(harness.model.trackedFiles[main.id] != nil)
    _ = harness.model.fileTreeRows(of: main.id)

    harness.model.select(other)
    harness.model.readFilesPanel(of: other.id)
    #expect(harness.model.trackedFiles[main.id] == nil)
    #expect(harness.model.fileTreeCache[main.id] == nil)

    try await waitUntil { harness.model.trackedFiles[other.id] != nil }
    try #require(harness.model.trackedFiles[other.id] != nil)
    harness.model.setShowsFilesPanel(false)
    #expect(harness.model.trackedFiles[other.id] == nil)
  }

  @Test func aListingReadThatFailsStillRedrawsWhatWaitedOnIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let other = try await harness.createWorktree(onBranch: "other")
    try FileManager.default.removeItem(at: other.path)
    let landingsBefore = harness.model.fileTreeBuildLandings

    harness.model.scheduleTrackedFilesRead(of: other.id)
    try await waitUntil { harness.model.pendingTrackedFilesReads[other.id] == nil }

    #expect(harness.model.trackedFiles[other.id] == nil)
    #expect(harness.model.fileTreeBuildLandings == landingsBefore + 1)
  }

  @Test func comingBackToAWorktreeRereadsItsOpenIgnoredFolder() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    let other = try await harness.createWorktree(onBranch: "other")
    let leftPad = try await harness.openIgnoredFolder(in: main)
    harness.model.select(other)
    harness.model.readFilesPanel(of: other.id)
    try FileManager.default.removeItem(at: leftPad)

    harness.model.select(main)
    harness.model.readFilesPanel(of: main.id)

    try await waitUntil { !harness.listsLeftPad(in: main) }
    #expect(!harness.listsLeftPad(in: main))
  }

  @Test func aSubmoduleStatusGitCannotReadKeepsTheLastReading() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    let sub = main.path.appending(path: "sub")
    try await TestRepository.initialise(at: sub, withFirstCommit: true, using: harness.git)
    try "x\n".write(to: sub.appending(path: "new.txt"), atomically: true, encoding: .utf8)
    harness.model.scheduleSubmoduleRead("sub", in: main.id)
    try await waitUntil { harness.model.submoduleReadings[main.id]?["sub"]?.status != nil }
    let first = try #require(harness.model.submoduleReadings[main.id]?["sub"])
    try #require(first.status?.untrackedPaths.isEmpty == false)
    try harness.wrapGit(in: #"case "$*" in *status*) exit 128 ;; esac"#)

    harness.model.scheduleSubmoduleRead("sub", in: main.id)
    try await waitUntil { !harness.model.panelFolderReads.isRunning { _ in true } }

    #expect(harness.model.submoduleReadings[main.id]?["sub"] == first)
  }

  @Test func submoduleReadsAskedForWhileOneRunsWaitForIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    let git = try #require(harness.model.coordinator?.git)
    git.runLog.setRecording(true)
    defer { git.runLog.setRecording(false) }
    _ = git.runLog.drain()

    for _ in 0..<5 { harness.model.scheduleSubmoduleRead("src", in: main.id) }

    try await waitUntil { harness.model.submoduleReadings[main.id]?["src"] != nil }
    try #require(harness.model.submoduleReadings[main.id]?["src"] != nil)
    #expect(git.runLog.drain().startedCount == 1)
  }

  @Test func aFolderOpenedJustBeforeThePanelShutIsReadWhenItOpensAgain() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    let row = try await harness.ignoredFolderRow(in: main)

    harness.model.toggleFolder(row, in: main.id)
    harness.model.setShowsFilesPanel(false)
    harness.model.setShowsFilesPanel(true)

    try await waitUntil { harness.listsLeftPad(in: main) }
    #expect(harness.listsLeftPad(in: main))
  }

  @Test func aFolderReadQueuedBeforeGitStopsIgnoringItLeavesItUngreyed() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    _ = try await harness.openIgnoredFolder(in: main)
    try await waitUntil { !harness.model.ignoredEntriesReads.isRunning(main.id) }
    try #require(!harness.model.ignoredEntriesReads.isRunning(main.id))
    let read = PanelFolderRead(kind: .ignoredFolder, path: "node_modules", worktreeID: main.id)
    harness.model.scheduleIgnoredFolderRead("node_modules", in: main.id)
    harness.model.scheduleIgnoredFolderRead("node_modules", in: main.id)

    try "".write(
      to: main.path.appending(path: ".git/info/exclude"),
      atomically: true,
      encoding: .utf8,
    )
    harness.model.scheduleIgnoredEntriesRead(of: main.id)
    try await waitUntil {
      harness.model.ignoredEntries[main.id]?.contains("node_modules/") == false
    }
    try #require(harness.model.ignoredEntries[main.id]?.contains("node_modules/") == false)
    try await waitUntil { !harness.model.panelFolderReads.isRunning(read) }
    try #require(!harness.model.panelFolderReads.isRunning(read))

    #expect(harness.model.ignoredFolderEntries[main.id]?["node_modules"] == nil)
  }

  @Test func aFolderGitStopsIgnoringListsItsFilesUngreyed() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    _ = try await harness.openIgnoredFolder(in: main)

    try "".write(
      to: main.path.appending(path: ".git/info/exclude"),
      atomically: true,
      encoding: .utf8,
    )
    harness.model.scheduleIgnoredEntriesRead(of: main.id)
    try await waitUntil {
      harness.model.ignoredEntries[main.id]?.contains("node_modules/") == false
    }
    _ = await harness.model.refreshStatus(of: main.id, forced: true)

    let row = harness.model.fileTreeRows(of: main.id).first { $0.path == "node_modules/left-pad" }
    #expect(row?.isIgnored == false)
  }
}
