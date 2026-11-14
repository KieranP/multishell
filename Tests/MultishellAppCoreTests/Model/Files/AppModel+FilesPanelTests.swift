import Foundation
import MultishellCore
import MultishellServices
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite(.serialized) @MainActor
struct AppModelFilesPanelTests {
  @Test func aClickOnTheGitBadgeOpensThePanelOnItsChangesListUnderModified() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.setFilesPanelFilterText("x", in: main.id)
    harness.model.setChangeScope(.branch)

    harness.model.showModifiedFiles(of: main)

    #expect(harness.model.showsFilesPanel)
    #expect(harness.model.workspace.selectedWorktreeID == main.id)
    #expect(harness.model.filesPanelState(of: main.id).mode == .changes)
    #expect(harness.model.workspace.changeScope == .modified, "what the badge counts")
    #expect(harness.model.filesPanelState(of: main.id).filterText == "")
  }

  @Test func onlyAListOfFilesFitsThePanelToItsRows() throws {
    let harness = Harness()
    harness.model.remoteState.connections = ServiceConnections(
      standIn: try ServiceStandIn(json: "{}")
    )
    var measuredPages: [FilesPanelMode] = []
    func widthOnDoubleClick(on mode: FilesPanelMode) -> Double {
      harness.model.setFilesPanelMode(mode)
      return harness.model.filesPanelWidthOnDoubleClick {
        measuredPages.append(mode)
        return 512
      }
    }

    #expect(widthOnDoubleClick(on: .changes) == 512)
    #expect(widthOnDoubleClick(on: .pullRequest) == FilesPanelWidth.initial)
    #expect(measuredPages == [.changes], "a services' page lays out no rows")
  }

  @Test func aClickOnTheRowsPullRequestGlyphOpensThePanelOnThePullRequestPage() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))

    harness.model.showFilesPanel(.pullRequest, of: main)

    #expect(harness.model.showsFilesPanel)
    #expect(harness.model.workspace.selectedWorktreeID == main.id)
    #expect(harness.model.workspace.filesPanelMode == .pullRequest)
  }

  @Test func aClickOnTheRowsCIGlyphOpensThePanelOnTheCIPage() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))

    harness.model.showFilesPanel(.ciRuns, of: main)

    #expect(harness.model.showsFilesPanel)
    #expect(harness.model.workspace.selectedWorktreeID == main.id)
    #expect(harness.model.workspace.filesPanelMode == .ciRuns)
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

  @Test func theWorktreeHeaderCarriesThePanelsToggleOnlyWhileThePanelIsShut() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    #expect(!harness.model.worktreeHeaderShowsFilesPanelToggle, "no worktree in view")

    harness.model.select(try #require(harness.worktree(onBranch: "main")))
    #expect(harness.model.worktreeHeaderShowsFilesPanelToggle)

    harness.model.setShowsFilesPanel(true)
    #expect(!harness.model.worktreeHeaderShowsFilesPanelToggle, "the panel's own header has it")
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
    await harness.model.openFileAsTab("left/b.txt", in: main.id)
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
    await harness.model.openFileAsTab("node_modules/left-pad/index.js", in: main.id)
    let tab = try #require(harness.model.workspace.fileTabs.first)
    try await waitUntil { harness.model.fileTabReadings[tab.id] != nil }
    try #require(harness.model.fileTabReadings[tab.id] != nil)

    #expect(harness.model.changeKind(of: tab) == nil, "shown as it is, not as every line added")
  }
}
