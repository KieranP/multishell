import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit

@MainActor
@Suite
struct AppModelAllChangesIndexTests {
  @Test func aChangesRowShowsTheAllChangesTabAtItsFileRatherThanOpeningItsOwnTab() async throws {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.setFilesPanelMode(.changes)

    await harness.model.activateFileRow("Sources/App.swift", in: harness.main.id)

    let tab = try #require(harness.model.workspace.allChangesTab(in: harness.main.id))
    #expect(harness.model.workspace.activeWorkspaceTab(in: harness.main.id)?.id == tab.id)
    #expect(harness.model.workspace.fileTabs.isEmpty)
    #expect(harness.model.takeAllChangesFileReveal(tab.id) == "Sources/App.swift")
    #expect(harness.model.takeAllChangesFileReveal(tab.id) == nil, "taken once")
  }

  @Test func aChangesRowTheTabDoesNotListLeavesTheAllChangesTabUnopened() async {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.setFilesPanelMode(.changes)
    var status = WorktreeStatus()
    status.setChanges([StatusChange(path: "a.txt", kind: .modified, lines: .notCounted)])
    harness.model.statuses[harness.main.id] = status

    await harness.model.activateFileRow("sub/x.c", in: harness.main.id)

    #expect(harness.model.workspace.allChangesTab(in: harness.main.id) == nil)
  }

  @Test func aChangedSubmodulesRowLeavesTheAllChangesTabUnopened() async throws {
    let harness = Harness()
    try FileManager.default.createDirectory(
      at: harness.main.path.appending(path: "sub"),
      withIntermediateDirectories: true,
    )
    harness.model.select(harness.main)
    harness.model.setFilesPanelMode(.changes)
    var status = WorktreeStatus()
    status.setChanges([StatusChange(path: "sub", kind: .modified, lines: .notCounted)])
    harness.model.statuses[harness.main.id] = status

    await harness.model.activateFileRow("sub", in: harness.main.id)

    #expect(harness.model.workspace.allChangesTab(in: harness.main.id) == nil)
  }

  @Test func aChangesRowExpandsItsFileWhereTheTabHadItCollapsed() async throws {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.setFilesPanelMode(.changes)
    let tab = try #require(harness.model.openAllChangesTab(in: harness.main.id))
    harness.model.toggleAllChangesFileCollapsed("a.swift", in: tab.id)
    harness.model.toggleAllChangesFileCollapsed("b.swift", in: tab.id)

    await harness.model.activateFileRow("a.swift", in: harness.main.id)

    #expect(harness.model.allChangesCollapsedFiles[tab.id]?.contains("a.swift") != true)
    #expect(harness.model.allChangesCollapsedFiles[tab.id]?.contains("b.swift") == true)
  }

  @Test func aSecondRowTurnsToTheSameTabAndAsksForItsOwnFile() async throws {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.setFilesPanelMode(.changes)
    await harness.model.activateFileRow("a.swift", in: harness.main.id)
    harness.model.newTab()

    await harness.model.activateFileRow("b.swift", in: harness.main.id)

    let tab = try #require(harness.model.workspace.allChangesTab(in: harness.main.id))
    #expect(harness.model.workspace.allChangesTabs.count == 1)
    #expect(harness.model.workspace.activeWorkspaceTab(in: harness.main.id)?.id == tab.id)
    #expect(harness.model.takeAllChangesFileReveal(tab.id) == "b.swift")
  }

  @Test func theRowOfTheFileAtTheTopOfTheAllChangesTabInFrontIsLit() throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = try #require(harness.model.openAllChangesTab(in: harness.main.id))

    harness.model.noteAllChangesTopFile(
      AllChangesTopFile(path: "b.swift", isHeaderScrolledPast: true),
      in: tab.id,
    )

    #expect(harness.model.shownFilePath(in: harness.main.id) == "b.swift")
    harness.model.newTab()
    #expect(harness.model.shownFilePath(in: harness.main.id) == nil, "lit only while in front")
  }

  @Test func aClickedRowIsLitAtOnceThoughTheTabMayNotScrollItsFileToTheTop() async throws {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.setFilesPanelMode(.changes)
    await harness.model.activateFileRow("a.swift", in: harness.main.id)
    let tab = try #require(harness.model.workspace.allChangesTab(in: harness.main.id))
    harness.model.noteAllChangesTopFile(
      AllChangesTopFile(path: "a.swift", isHeaderScrolledPast: false),
      in: tab.id,
    )

    await harness.model.activateFileRow("b.swift", in: harness.main.id)

    #expect(harness.model.shownFilePath(in: harness.main.id) == "b.swift")
  }
}
