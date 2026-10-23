import Foundation
import MultishellCore
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite(.serialized) @MainActor
struct AppModelFileTabChangeKindTests {
  private static func status(_ path: String, _ kind: StatusChange.Kind) -> WorktreeStatus {
    var status = WorktreeStatus()
    status.setChanges([
      StatusChange(path: path, kind: kind, lines: .counted(insertions: 1, deletions: 0))
    ])
    return status
  }

  @Test func anEmptyNewFilesTabIsAdded() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    try "".write(to: main.path.appending(path: "new.txt"), atomically: true, encoding: .utf8)
    _ = await harness.model.refreshStatus(of: main.id)
    let (tab, _) = try harness.openFileTab("new.txt")

    try await waitUntil { harness.model.fileTabReadings[tab.id] != nil }

    #expect(harness.model.changeKind(of: tab) == .added)
  }

  @Test func aFileCommittedEmptyThatNowHasLinesIsModifiedAsItsStatusSays() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    try await TestRepository.commit(
      "empty",
      files: ["empty.txt": ""],
      in: main.path,
      using: harness.git,
    )
    try "one\n".write(
      to: main.path.appending(path: "empty.txt"),
      atomically: true,
      encoding: .utf8,
    )
    _ = await harness.model.refreshStatus(of: main.id)
    let (tab, _) = try harness.openFileTab("empty.txt")

    try await waitUntil { harness.model.fileTabReadings[tab.id] != nil }

    #expect(harness.model.statuses[main.id]?.changes.first?.kind == .modified)
    #expect(harness.model.changeKind(of: tab) == .modified)
  }

  @Test func aHiddenTabInANestedRepositoryTakesItsDotFromTheInnermost() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    harness.model.setShowsFilesPanel(true)
    let tab = try #require(harness.store.openFileTab(path: "sub/inner/x.txt", in: main.id))
    harness.model.filesPanelStates[main.id] = FilesPanelState(expandedFolders: ["sub", "sub/inner"])
    harness.model.submoduleReadings[main.id] = [
      "sub": SubmoduleReading(tracked: .empty, status: Self.status("inner", .modified)),
      "sub/inner": SubmoduleReading(tracked: .empty, status: Self.status("x.txt", .added)),
    ]

    harness.model.fileTabReadings[tab.id] = FileTabReading(
      content: .releasedFollowingStatus,
      isFileGone: false,
    )

    #expect(harness.model.changeKind(of: tab) == .added)
  }

  @Test(arguments: [true, false])
  func aSubmoduleNoLongerReadGivesNoDotFromItsLastReading(panelIsShut: Bool) async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    if panelIsShut {
      harness.model.filesPanelStates[main.id] = FilesPanelState(expandedFolders: ["sub"])
    } else {
      harness.model.setShowsFilesPanel(true)
    }
    let tab = try #require(harness.store.openFileTab(path: "sub/x.txt", in: main.id))
    harness.model.submoduleReadings[main.id] = [
      "sub": SubmoduleReading(tracked: .empty, status: Self.status("x.txt", .deleted))
    ]

    harness.model.fileTabReadings[tab.id] = FileTabReading(
      content: .releasedFollowingStatus,
      isFileGone: false,
    )

    #expect(harness.model.changeKind(of: tab) == nil)
  }

  @Test func hidingATabWithNoDotGivesItNone() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, main) = try harness.openFileTab()
    let readme = main.path.appending(path: "README.md")
    let text = try String(contentsOf: readme, encoding: .utf8)
    try "staged\n".write(to: readme, atomically: true, encoding: .utf8)
    _ = try await harness.git.run(["add", "README.md"], in: main.path)
    try text.write(to: readme, atomically: true, encoding: .utf8)
    _ = await harness.model.refreshStatus(of: main.id, forced: true)
    harness.model.noteFileTabChanged(tab.id)
    _ = try #require(await harness.rowsArrive(in: tab.id))
    #expect(harness.model.changeKind(of: tab) == nil)

    harness.model.newShellTab()

    #expect(harness.model.fileTabReadings[tab.id]?.content.isReleased == true)
    #expect(harness.model.changeKind(of: tab) == nil)
  }
}
