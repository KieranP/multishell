import Foundation
import MultishellCore
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite(.serialized) @MainActor
struct AppModelFilesPanelTests {
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

  @Test func sourcesThatRevertWhileABuildRunsShowTheirOwnRows() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    harness.model.trackedFiles[main.id] = TrackedFiles(
      paths: (0..<30_000).map { "src/file\($0).txt" },
      submodulePaths: [],
      notCheckedOutPaths: [],
      isCapped: false,
    )
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

  @Test func aLargeBuildOvertakenByASmallListingIsNotKept() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    let tracked = { (count: Int) in
      TrackedFiles(
        paths: (0..<count).map { "src/file\($0).txt" },
        submodulePaths: [],
        notCheckedOutPaths: [],
        isCapped: false,
      )
    }
    harness.model.trackedFiles[main.id] = tracked(30_000)
    _ = harness.model.fileTreeRows(of: main.id)

    harness.model.trackedFiles[main.id] = tracked(3)
    _ = harness.model.fileTreeRows(of: main.id)

    try await waitUntil { harness.model.pendingFileTreeListings[main.id] == nil }
    #expect(harness.model.pendingFileTreeListings[main.id] == nil)
    #expect(harness.model.fileTreeListings[main.id] == nil)
  }
}
