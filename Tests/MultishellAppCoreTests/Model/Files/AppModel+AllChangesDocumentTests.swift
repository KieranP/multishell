import Foundation
import Observation
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@MainActor
@Suite
struct AppModelAllChangesDocumentTests {
  private static let paths = ["a.txt", "b.txt", "c.txt"]

  private static func tabWithThreeFiles(_ harness: Harness) throws -> AllChangesTab {
    harness.model.select(harness.main)
    let tab = try #require(harness.model.openAllChangesTab(in: harness.main.id))
    harness.model.allChangesReadings[tab.id] = .sample(
      rows: paths.map { path in
        (
          path,
          FileTabRows(
            lines: [DiffLine(kind: .added, oldNumber: nil, newNumber: 1, text: path)],
            marksStaging: true,
          ),
        )
      }
    )
    return tab
  }

  @Test func aRelayoutKeepsTheFindSelectionInItsOwnFileWhereAnotherHasTheSameLine() throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = try #require(harness.model.openAllChangesTab(in: harness.main.id))
    let rows = FileTabRows(
      lines: ["x", "same"].enumerated().map { index, text in
        DiffLine(kind: .added, oldNumber: nil, newNumber: index + 1, text: text)
      },
      marksStaging: true,
    )
    harness.model.allChangesReadings[tab.id] = .sample(
      rows: [("a.txt", rows), ("b.txt", rows), ("c.txt", rows)]
    )
    harness.model.showFind()
    harness.model.setFindText("same", of: tab.id)
    harness.model.findNext(in: tab.id)
    try #require(harness.model.selectedFileFindMatch(of: tab.id) == 1)

    harness.model.toggleAllChangesFileCollapsed("c.txt", in: tab.id)

    #expect(harness.model.selectedFileFindMatch(of: tab.id) == 1)
  }

  @Test func aReadUnderAnotherBaseKeepsTheFindSelectionForTheReadThatLands() throws {
    let harness = Harness()
    let tab = try Self.tabWithThreeFiles(harness)
    let read = try #require(harness.model.allChangesReadings[tab.id])
    harness.model.showFind()
    harness.model.setFindText("txt", of: tab.id)
    harness.model.findNext(in: tab.id)
    try #require(harness.model.selectedFileFindMatch(of: tab.id) == 1)

    harness.model.allChangesReadings[tab.id] = AllChangesReading(
      listed: read.listed,
      files: read.files,
      baseName: "main",
    )
    harness.model.rerunFileFind(in: tab.id)
    harness.model.allChangesReadings[tab.id] = read
    harness.model.rerunFileFind(in: tab.id)

    #expect(harness.model.selectedFileFindMatch(of: tab.id) == 1)
  }

  @Test func collapsingEveryFileCollapsesEachOneListed() throws {
    let harness = Harness()
    let tab = try Self.tabWithThreeFiles(harness)

    harness.model.toggleEveryAllChangesFileCollapsed(in: tab.id)

    #expect(
      Self.paths.allSatisfy { harness.model.allChangesCollapsedFiles[tab.id]?.contains($0) == true }
    )
    #expect(harness.model.isEveryAllChangesFileCollapsed(in: tab.id))
  }

  @Test func withOneFileStillExpandedTheToggleCollapsesTheRest() throws {
    let harness = Harness()
    let tab = try Self.tabWithThreeFiles(harness)
    harness.model.toggleAllChangesFileCollapsed("a.txt", in: tab.id)
    harness.model.toggleAllChangesFileCollapsed("b.txt", in: tab.id)
    #expect(!harness.model.isEveryAllChangesFileCollapsed(in: tab.id))

    harness.model.toggleEveryAllChangesFileCollapsed(in: tab.id)

    #expect(
      Self.paths.allSatisfy { harness.model.allChangesCollapsedFiles[tab.id]?.contains($0) == true }
    )
  }

  @Test func withEveryFileCollapsedTheToggleExpandsThemAll() throws {
    let harness = Harness()
    let tab = try Self.tabWithThreeFiles(harness)
    harness.model.toggleEveryAllChangesFileCollapsed(in: tab.id)

    harness.model.toggleEveryAllChangesFileCollapsed(in: tab.id)

    #expect(
      Self.paths.allSatisfy { harness.model.allChangesCollapsedFiles[tab.id]?.contains($0) != true }
    )
    #expect(!harness.model.isEveryAllChangesFileCollapsed(in: tab.id))
  }

  @Test func aTabWithNoFilesReadIsNotEveryFileCollapsed() throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = try #require(harness.model.openAllChangesTab(in: harness.main.id))

    harness.model.toggleEveryAllChangesFileCollapsed(in: tab.id)

    #expect(!harness.model.isEveryAllChangesFileCollapsed(in: tab.id))
  }

  @Test func aHeaderPushedAlongWithinOneFileLeavesTheLitRowsAlone() throws {
    let harness = Harness()
    let tab = try Self.tabWithThreeFiles(harness)
    let top = { (scrolledTo: Double) in
      AllChangesTopFile(
        path: "a.txt",
        headerBarTop: 0,
        nextHeaderBarTop: 100,
        scrolledTo: scrolledTo,
        barHeight: 30,
      )
    }
    harness.model.noteAllChangesTopFile(top(75), in: tab.id)
    let lit = AtomicFlag()
    withObservationTracking {
      _ = harness.model.shownFilePath(in: harness.main.id)
    } onChange: {
      lit.raise()
    }

    harness.model.noteAllChangesTopFile(top(80), in: tab.id)

    #expect(!lit.raised)
  }

  @Test func aReadingUnderModifiedShowsNothingOnceTheTabCountsFromTheBranchesBase() throws {
    let harness = Harness()
    harness.model.defaultBranchScans[harness.project.id] = .found(.sample("main"))
    let tab = try Self.tabWithThreeFiles(harness)
    #expect(harness.model.allChangesDocument(of: tab.id) != nil)

    harness.model.setChangeScope(.branch)

    #expect(harness.model.allChangesDocument(of: tab.id) == nil)
  }
}
