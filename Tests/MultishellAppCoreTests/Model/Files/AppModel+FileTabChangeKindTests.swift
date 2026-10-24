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
    let main = try #require(harness.worktree(onBranch: "main"))
    let readme = main.path.appending(path: "README.md")
    let text = try String(contentsOf: readme, encoding: .utf8)
    try "staged\n".write(to: readme, atomically: true, encoding: .utf8)
    _ = try await harness.git.run(["add", "README.md"], in: main.path)
    try text.write(to: readme, atomically: true, encoding: .utf8)
    _ = await harness.model.refreshStatus(of: main.id, forced: true)
    let (tab, _) = try harness.openFileTab()
    _ = try #require(await harness.rowsArrive(in: tab.id))
    #expect(harness.model.statuses[main.id]?.changes.isEmpty == false)
    #expect(harness.model.changeKind(of: tab) == nil)

    harness.model.newShellTab()

    #expect(harness.model.fileTabReadings[tab.id]?.content.isReleased == true)
    #expect(harness.model.changeKind(of: tab) == nil)
  }

  @Test func underBranchABinaryFileTheBranchAddedWearsTheBranchListsDot() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureInGitList()
    try Data([0, 1, 2, 0]).write(to: feature.path.appending(path: "blob.bin"))
    _ = try await harness.git.run(["add", "blob.bin"], in: feature.path)
    _ = try await harness.git.run(["commit", "-q", "-m", "blob"], in: feature.path)
    await harness.model.refreshStatuses()
    harness.model.setChangeScope(.branch)
    let tab = try #require(harness.model.openFileTab("blob.bin", in: feature))

    try await waitUntil {
      harness.model.fileTabReadings[tab.id] != nil && harness.model.branchChanges[feature.id] != nil
    }

    #expect(harness.model.changeKind(of: tab) == .added, "clean against HEAD, new since the base")
  }

  @Test func underBranchAHiddenTabInASubmoduleStillTakesItsDotFromTheSubmodule() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    harness.model.setFilesPanelMode(.git)
    harness.model.setShowsFilesPanel(true)
    await harness.model.refreshBranchScan(of: harness.project)
    harness.model.setChangeScope(.branch)
    let tab = try #require(harness.store.openFileTab(path: "sub/x.txt", in: main.id))
    harness.model.filesPanelStates[main.id] = FilesPanelState(expandedFolders: ["sub"])
    harness.model.submoduleReadings[main.id] = [
      "sub": SubmoduleReading(tracked: .empty, status: Self.status("x.txt", .added))
    ]
    harness.model.branchChanges[main.id] = BranchChanges(
      baseName: "main",
      mergeBase: "abc",
      changes: [StatusChange(path: "sub", kind: .modified, lines: .unscored)],
    )

    harness.model.fileTabReadings[tab.id] = FileTabReading(
      content: .releasedFollowingStatus,
      isFileGone: false,
    )

    #expect(harness.model.changeKind(of: tab) == .added)
  }

  @Test func aHiddenTabsDotFollowsANewScope() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureInGitList()
    try await TestRepository.commit(
      "work",
      files: ["work.txt": "work\n"],
      in: feature.path,
      using: harness.git,
    )
    await harness.model.refreshStatuses()
    let tab = try #require(harness.model.openFileTab("work.txt", in: feature))
    _ = try #require(harness.model.openFileTab("README.md", in: feature))
    harness.model.fileTabReadings[tab.id] = FileTabReading(
      content: .released(changeKind: nil),
      isFileGone: false,
    )

    harness.model.setChangeScope(.branch)
    try await waitUntil { harness.model.branchChanges[feature.id] != nil }

    #expect(harness.model.changeKind(of: tab) == .added, "new since the base")
  }

  @Test func aHiddenTabForAFileOutOfTheIndexButOnDiskWearsTheNewFilesDot() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    let tab = try #require(harness.store.openFileTab(path: "a.txt", in: main.id))
    var status = WorktreeStatus()
    status.setChanges([
      StatusChange(path: "a.txt", kind: .deleted, lines: .counted(insertions: 0, deletions: 1)),
      StatusChange(path: "a.txt", kind: .added, lines: .counted(insertions: 1, deletions: 0)),
    ])
    harness.model.statuses[main.id] = status

    harness.model.fileTabReadings[tab.id] = FileTabReading(
      content: .releasedFollowingStatus,
      isFileGone: false,
    )

    #expect(harness.model.changeKind(of: tab) == .added)
  }

  @Test func underBranchWithThePanelOnFilesANewFileEditedSinceIsStillAdded() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureInGitList()
    try await TestRepository.commit(
      "add",
      files: ["new.txt": "one\n"],
      in: feature.path,
      using: harness.git,
    )
    try "one\ntwo\n".write(
      to: feature.path.appending(path: "new.txt"),
      atomically: true,
      encoding: .utf8,
    )
    await harness.model.refreshStatuses()
    harness.model.setFilesPanelMode(.files)
    harness.model.setChangeScope(.branch)
    let tab = try #require(harness.model.openFileTab("new.txt", in: feature))

    let rows = try #require(try await harness.rowsArrive(in: tab.id))
    try await waitUntil { harness.lineCounts(of: tab)?.insertions == 2 }
    try #require(harness.lineCounts(of: tab)?.insertions == 2, "\(rows.lineCounts)")

    #expect(harness.model.changeKind(of: tab) == .added, "new since the base, though edited since")
  }

  @Test func underBranchWithNoSharedHistoryAHiddenTabTakesItsDotFromTheStatus() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureInGitList()
    harness.model.setChangeScope(.branch)
    let tab = try #require(harness.store.openFileTab(path: "a.txt", in: feature.id))
    harness.model.statuses[feature.id] = Self.status("a.txt", .modified)
    harness.model.branchChanges[feature.id] = BranchChanges(
      baseName: "main",
      mergeBase: nil,
      changes: [],
    )

    harness.model.fileTabReadings[tab.id] = FileTabReading(
      content: .releasedFollowingStatus,
      isFileGone: false,
    )

    #expect(harness.model.changeKind(of: tab) == .modified, "counted from HEAD, as the tab is")
  }

  @Test func aHiddenTabsDotFollowsTheBaseOnceItResolves() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureInGitList()
    try await TestRepository.commit(
      "work",
      files: ["work.txt": "work\n"],
      in: feature.path,
      using: harness.git,
    )
    await harness.model.refreshStatuses()
    harness.model.setChangeScope(.branch)
    let tab = try #require(harness.model.openFileTab("work.txt", in: feature))
    _ = try #require(harness.model.openFileTab("README.md", in: feature))
    harness.model.defaultBranchScans[harness.project.id] = nil
    harness.model.fileTabReadings[tab.id] = FileTabReading(
      content: .released(changeKind: nil),
      isFileGone: false,
    )

    await harness.model.refreshBranchScan(of: harness.project)
    try await waitUntil { harness.model.branchChanges[feature.id] != nil }

    #expect(harness.model.changeKind(of: tab) == .added, "new since the base")
  }

  @Test func aNewDiffAlgorithmLeavesAHiddenTabsDotAsItWas() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureInGitList()
    harness.model.setFilesPanelMode(.files)
    harness.model.setChangeScope(.branch)
    let tab = try #require(harness.store.openFileTab(path: "README.md", in: feature.id))
    harness.model.fileTabReadings[tab.id] = FileTabReading(
      content: .released(changeKind: .modified),
      isFileGone: false,
    )

    harness.model.setDiffAlgorithm(.myers)

    #expect(harness.model.changeKind(of: tab) == .modified)
  }
}
