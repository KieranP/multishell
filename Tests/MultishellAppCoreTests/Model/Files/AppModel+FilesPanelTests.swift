import Foundation
import MultishellCore
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite(.serialized) @MainActor
struct AppModelFilesPanelTests {
  private static func modified(_ count: Int) -> WorktreeStatus {
    var status = WorktreeStatus()
    status.setChanges(
      (0..<count).map { number in
        StatusChange(
          path: "src/file\(number).txt",
          kind: .modified,
          lines: .counted(insertions: 1, deletions: 0),
        )
      }
    )
    return status
  }

  private static func tracked(_ count: Int) -> TrackedFiles {
    TrackedFiles(
      paths: (0..<count).map { "src/file\($0).txt" },
      submodulePaths: [],
      notCheckedOutPaths: [],
      isCapped: false,
    )
  }

  @Test func aClickOnTheGitBadgeOpensThePanelOnModified() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.setFilesPanelFilterText("x", in: main.id)

    harness.model.showModifiedFiles(of: main)

    #expect(harness.model.showsFilesPanel)
    #expect(harness.model.workspace.selectedWorktreeID == main.id)
    #expect(harness.model.filesPanelState(of: main.id).mode == .modified)
    #expect(harness.model.filesPanelState(of: main.id).filterText == "")
  }

  @Test func theOpenPanelListsTheIndexAndNewFiles() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    try "x\n".write(to: main.path.appending(path: "new.txt"), atomically: true, encoding: .utf8)

    harness.model.setShowsFilesPanel(true)

    try await waitUntil {
      harness.model.fileTreeRows(of: main.id).map(\.name) == ["new.txt", "README.md"]
    }
    #expect(harness.model.filesPanelSummary(of: main.id).changedFiles == 1)
  }

  @Test func thePanelIsOnScreenOnlyWhereItIsOpenAndAWorktreeIsInView() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.setShowsFilesPanel(true)
    #expect(!harness.model.isFilesPanelOnScreen, "no worktree in view")

    harness.model.select(try #require(harness.worktree(onBranch: "main")))
    #expect(harness.model.isFilesPanelOnScreen)

    harness.model.setShowsFilesPanel(false)
    #expect(!harness.model.isFilesPanelOnScreen)
  }

  @Test func aPathASparseCheckoutLeavesOffDiskListsGreyedAndDoesNotOpen() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    try await TestRepository.commit(
      "two folders",
      files: ["kept/a.txt": "a\n", "left/b.txt": "b\n"],
      in: main.path,
      using: harness.git,
    )
    _ = try await harness.git.run(["sparse-checkout", "set", "kept"], in: main.path)
    harness.model.select(main)
    harness.model.setShowsFilesPanel(true)
    try await waitUntil { harness.model.fileTreeRows(of: main.id).contains { $0.path == "left" } }
    let folder = try #require(harness.model.fileTreeRows(of: main.id).first { $0.path == "left" })
    harness.model.toggleFolder(folder, in: main.id)

    let row = try #require(
      harness.model.fileTreeRows(of: main.id).first { $0.path == "left/b.txt" }
    )
    #expect(!row.isOpenable)
    await harness.model.openFileFromPanel("left/b.txt", in: main.id)
    #expect(harness.model.workspace.fileTabs.isEmpty)
    #expect(harness.platform.beeps == 1)
  }

  @Test func anIgnoredFolderListsGreyedOpensAndItsFilesOpenPlain() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    _ = try await harness.openIgnoredFolder(in: main)
    let rows = { harness.model.fileTreeRows(of: main.id) }
    let folder = try #require(rows().first { $0.path == "node_modules" })
    #expect(folder.isIgnored && folder.isFolder)
    let leftPad = try #require(rows().first { $0.path == "node_modules/left-pad" })
    #expect(leftPad.isIgnored && leftPad.isFolder)
    harness.model.toggleFolder(leftPad, in: main.id)
    try await waitUntil { rows().contains { $0.path.hasPrefix("node_modules/left-pad/") } }
    await harness.model.openFileFromPanel("node_modules/left-pad/index.js", in: main.id)
    let tab = try #require(harness.model.workspace.fileTabs.first)
    try await waitUntil { harness.model.fileTabReadings[tab.id] != nil }

    #expect(harness.model.changeKind(of: tab) == nil, "shown as it is, not as every line added")
  }

  @Test func aLargeListingIsBuiltOffTheMainActorAndShownOnceBuilt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    let paths = (0..<30_000).map { "src/file\($0).txt" }
    harness.model.trackedFiles[main.id] = TrackedFiles(
      paths: paths,
      submodulePaths: [],
      notCheckedOutPaths: [],
      isCapped: false,
    )

    let first = harness.model.fileTreeRows(of: main.id)
    try await waitUntil { !harness.model.fileTreeRows(of: main.id).isEmpty }

    #expect(first.isEmpty, "built in place, which held the main actor")
    #expect(harness.model.fileTreeRows(of: main.id).map(\.name) == ["src"])
  }

  @Test func aLargeChangeSetIsBuiltOffTheMainActorAndShownOnceBuilt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    harness.model.setFilesPanelMode(.modified)
    var status = Self.modified(30_000)
    harness.model.statuses[main.id] = status

    let first = harness.model.fileTreeRows(of: main.id)
    try await waitUntil { !harness.model.fileTreeRows(of: main.id).isEmpty }

    #expect(first.isEmpty, "built in place, which held the main actor")
    #expect(harness.model.fileTreeRows(of: main.id).first?.name == "src")
    #expect(harness.model.filesPanelSummary(of: main.id).changedFiles == 30_000)

    status.setChanges(
      status.changes.map { change in
        StatusChange(
          path: change.path,
          kind: change.kind,
          lines: .counted(insertions: 2, deletions: 0),
        )
      }
    )
    harness.model.statuses[main.id] = status
    #expect(!harness.model.fileTreeRows(of: main.id).isEmpty)
    #expect(harness.model.pendingFileTreeChanges[main.id] == nil, "a count moving keeps the set")
  }

  @Test func aPanelWaitingOnALargeListingAndChangeSetDrawsThemOnceBothLand() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    harness.model.setFilesPanelMode(.modified)
    harness.model.trackedFiles[main.id] = Self.tracked(30_000)
    harness.model.statuses[main.id] = Self.modified(30_000)

    let renderer = FilesPanelRenderer(harness.model, showing: main.id)
    #expect(renderer.rows.isEmpty)
    try await waitUntil { !renderer.rows.isEmpty }

    #expect(!renderer.rows.isEmpty, "the second build to land redrew the panel")
  }

  @Test func aFilterTypedWhileALargeListingBuildsIsDrawnOnceItLands() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    harness.model.trackedFiles[main.id] = Self.tracked(30_000)
    let renderer = FilesPanelRenderer(harness.model, showing: main.id)

    harness.model.setFilesPanelFilterText("file1", in: main.id)
    try await waitUntil { !renderer.rows.isEmpty }

    #expect(!renderer.rows.isEmpty, "the landing redrew the filtered panel")
  }

  @Test func theFooterCountsTheChangedPathsWhileTheirSetBuilds() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    harness.model.statuses[main.id] = Self.modified(30_000)

    let summary = harness.model.filesPanelSummary(of: main.id)

    #expect(harness.model.pendingFileTreeChanges[main.id] != nil)
    #expect(summary.changedFiles == 30_000)
  }

  @Test func rendersWhileALargeListingBuildsReuseOneTreeAndItsRows() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    harness.model.trackedFiles[main.id] = Self.tracked(30_000)

    let first = harness.model.fileTreeRows(of: main.id)
    let kept = harness.model.fileTreeCache[main.id]

    #expect(harness.model.pendingFileTreeListings[main.id] != nil)
    #expect(kept?.rows?.rows == first)
    _ = harness.model.filesPanelSummary(of: main.id)
    #expect(harness.model.fileTreeCache[main.id]?.rows?.rows == first)
    try await waitUntil { !harness.model.fileTreeRows(of: main.id).isEmpty }
    #expect(harness.model.fileTreeRows(of: main.id).map(\.name) == ["src"])
  }

  @Test func sourcesThatRevertWhileABuildRunsShowTheirOwnRows() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    harness.model.trackedFiles[main.id] = Self.tracked(30_000)
    try await waitUntil { !harness.model.fileTreeRows(of: main.id).isEmpty }
    let clean = harness.model.statuses[main.id]
    var dirty = WorktreeStatus()
    dirty.setChanges([
      StatusChange(
        path: "src/file1.txt",
        kind: .deleted,
        lines: .counted(insertions: 0, deletions: 1),
      )
    ])
    harness.model.statuses[main.id] = dirty
    #expect(harness.model.fileTreeRows(of: main.id).first?.holdsChange == true)

    harness.model.statuses[main.id] = clean

    #expect(harness.model.fileTreeRows(of: main.id).first?.holdsChange == false)
  }

  @Test func aStatusThatRevertsWhileALargeChangeSetBuildsDrawsTheKeptSetAndDropsTheBuild()
    async throws
  {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    harness.model.setFilesPanelMode(.modified)
    harness.model.statuses[main.id] = Self.modified(3)
    _ = harness.model.fileTreeRows(of: main.id)
    harness.model.statuses[main.id] = Self.modified(30_000)
    _ = harness.model.fileTreeRows(of: main.id)

    harness.model.statuses[main.id] = Self.modified(3)

    #expect(harness.model.fileTreeRows(of: main.id).count == 4, "src and its three files")
    #expect(harness.model.fileTreeCache[main.id]?.awaitsChanges == false)
    try await waitUntil { harness.model.pendingFileTreeChanges[main.id] == nil }
    #expect(harness.model.pendingFileTreeChanges[main.id] == nil)
    #expect(harness.model.fileTreeChanges[main.id] == nil, "landed with nothing waiting for it")
  }

  @Test func aChangeSetThatFlipsAwayAndBackKeepsItsOneBuild() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    harness.model.statuses[main.id] = Self.modified(3)
    _ = harness.model.fileTreeRows(of: main.id)
    harness.model.statuses[main.id] = Self.modified(30_000)
    _ = harness.model.fileTreeRows(of: main.id)
    let first = try #require(harness.model.pendingFileTreeChanges[main.id])

    harness.model.statuses[main.id] = Self.modified(4)
    _ = harness.model.fileTreeRows(of: main.id)
    harness.model.statuses[main.id] = Self.modified(30_000)
    _ = harness.model.fileTreeRows(of: main.id)

    #expect(harness.model.pendingFileTreeChanges[main.id] == first, "a started build runs on")
  }

  @Test func aChangeSetThatShrinksLetsGoOfTheLargeOneBuiltForIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    harness.model.setFilesPanelMode(.modified)
    harness.model.statuses[main.id] = Self.modified(30_000)
    let renderer = FilesPanelRenderer(harness.model, showing: main.id)
    try await waitUntil { renderer.rows.count > 30_000 }

    harness.model.statuses[main.id] = Self.modified(3)
    try await waitUntil { renderer.rows.count == 4 }

    #expect(renderer.rows.count == 4, "src and its three files")
    #expect(harness.model.fileTreeChanges[main.id] == nil)
  }

  @Test func aListingThatShrinksLetsGoOfTheLargeOneBuiltForIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    harness.model.trackedFiles[main.id] = Self.tracked(30_000)
    let renderer = FilesPanelRenderer(harness.model, showing: main.id)
    try await waitUntil { !renderer.rows.isEmpty }

    harness.model.trackedFiles[main.id] = Self.tracked(3)
    try await waitUntil { harness.model.fileTreeCache[main.id]?.tree.listing.filePaths.count == 3 }

    #expect(harness.model.fileTreeCache[main.id]?.tree.listing.filePaths.count == 3)
    #expect(harness.model.fileTreeListings[main.id] == nil)
  }

  @Test func aLargeBuildOvertakenByASmallListingIsNotKept() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    harness.model.trackedFiles[main.id] = Self.tracked(30_000)
    _ = harness.model.fileTreeRows(of: main.id)

    harness.model.trackedFiles[main.id] = Self.tracked(3)
    _ = harness.model.fileTreeRows(of: main.id)

    try await waitUntil { harness.model.pendingFileTreeListings[main.id] == nil }
    #expect(harness.model.pendingFileTreeListings[main.id] == nil)
    #expect(harness.model.fileTreeListings[main.id] == nil)
  }
}
