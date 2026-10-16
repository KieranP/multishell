import Foundation
import MultishellCore
import MultishellGitKit
import TestScratch
import Testing

@testable import MultishellAppCore

@Suite(.serialized) @MainActor
struct AppModelFileFindTests {
  @Test func findInAFileTabCountsItsMatchesAndStepsThroughThem() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, main) = try harness.openFileTab()
    try "one\nTwo\nthree two\n".write(
      to: main.path.appending(path: "README.md"),
      atomically: true,
      encoding: .utf8,
    )
    harness.model.noteFileTabChanged(tab.id)
    try await waitUntil { harness.model.changeKind(of: tab) == .modified }

    harness.model.showFind()
    harness.model.setFindText("two", of: tab.id)

    #expect(harness.model.findBarTargetIDs.contains(tab.id))
    #expect(harness.model.findMatchCount(of: tab.id)?.text == t("find.count", 1, 2))
    harness.model.findNext()
    #expect(harness.model.selectedFileFindMatch(of: tab.id) == 1)
    harness.model.closeFind()
    #expect(harness.model.fileFindMatches(of: tab.id) == [])
    #expect(harness.model.fileTabFocusRequest == tab.id, "the keyboard goes back to the file")
  }

  @Test func aReReadKeepsTheSelectedMatch() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    try "a\na\na\n".write(
      to: main.path.appending(path: "README.md"),
      atomically: true,
      encoding: .utf8,
    )
    let (tab, _) = try harness.openFileTab()
    try await waitUntil { harness.model.fileTabReadings[tab.id] != nil }
    harness.model.showFind()
    harness.model.setFindText("a", of: tab.id)
    harness.model.findNext(in: tab.id)
    harness.model.findNext(in: tab.id)

    await harness.model.readFileTab(tab.id)

    #expect(harness.model.selectedFileFindMatch(of: tab.id) == 2)
  }

  @Test func anEmptiedFindTextShowsNoCountAsAPanesDoesNot() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, _) = try harness.openFileTab()
    try await waitUntil { harness.model.fileTabReadings[tab.id] != nil }
    harness.model.showFind()
    harness.model.setFindText("h", of: tab.id)

    harness.model.setFindText("", of: tab.id)

    #expect(harness.model.findMatchCount(of: tab.id) == nil)
  }

  @Test func aReReadThatAddsAMatchAboveDoesNotMoveTheSelection() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    let readme = main.path.appending(path: "README.md")
    try "xxxx\na\n".write(to: readme, atomically: true, encoding: .utf8)
    let (tab, _) = try harness.openFileTab()
    try await waitUntil { harness.model.fileTabReadings[tab.id] != nil }
    harness.model.showFind()
    harness.model.setFindText("a", of: tab.id)
    let moves = harness.model.fileFindSelectionMoves(of: tab.id)

    try "a\nxxxx\na\n".write(to: readme, atomically: true, encoding: .utf8)
    await harness.model.readFileTab(tab.id)

    #expect(harness.model.selectedFileFindMatch(of: tab.id) == 1)
    #expect(harness.model.fileFindSelectionMoves(of: tab.id) == moves)
  }

  @Test func aStepOverTheOnlyMatchStillMovesTheSelectionToIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, _) = try harness.openFileTab()
    try await waitUntil { harness.model.fileTabReadings[tab.id] != nil }
    harness.model.showFind()
    harness.model.setFindText("hello", of: tab.id)
    let moves = harness.model.fileFindSelectionMoves(of: tab.id)

    harness.model.findNext(in: tab.id)

    #expect(harness.model.fileFindSelectionMoves(of: tab.id) == moves + 1)
  }

  @Test(arguments: [true, false])
  func aTabKeepsItsFindSelectionThroughALayoutSwitchShownOrHidden(isHidden: Bool) async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    try "a1\na2\na3\n".write(
      to: main.path.appending(path: "README.md"),
      atomically: true,
      encoding: .utf8,
    )
    let (tab, _) = try harness.openFileTab()
    try await waitUntil { harness.model.fileTabReadings[tab.id] != nil }
    harness.model.showFind()
    harness.model.setFindText("a", of: tab.id)
    if isHidden { harness.model.newShellTab() }

    harness.model.setFileTabLayout(.split)
    if isHidden {
      harness.model.activateTab(tab.id)
      _ = try #require(await harness.rowsArrive(in: tab.id))
    }

    #expect(harness.model.selectedFileFindMatch(of: tab.id) == 0)
  }

  @Test func aSwitchToSplitKeepsTheMatchOnItsLineWhereLinesRepeat() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    try "a\na\na\n".write(
      to: main.path.appending(path: "README.md"),
      atomically: true,
      encoding: .utf8,
    )
    let (tab, _) = try harness.openFileTab()
    try await waitUntil { harness.model.fileTabReadings[tab.id] != nil }
    harness.model.showFind()
    harness.model.setFindText("a", of: tab.id)
    harness.model.findNext(in: tab.id)

    harness.model.setFileTabLayout(.split)

    #expect(harness.model.selectedFileFindMatch(of: tab.id) == 1)
  }

  @Test func aNewFindTextOnATabThatLetGoOfItsRowsDropsTheOldTextsMatches() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, _) = try harness.openFileTab()
    try await waitUntil { harness.model.fileTabReadings[tab.id] != nil }
    harness.model.showFind()
    harness.model.setFindText("h", of: tab.id)
    #expect(harness.model.fileFindResults[tab.id] != nil)
    harness.model.newShellTab()

    harness.model.setFindText("e", of: tab.id)

    #expect(harness.model.fileFindResults[tab.id]?.matches == [])
  }

  @Test func aNewSearchOnATabStillWithoutRowsCountsAsAMoveOnceTheyArrive() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, _) = try harness.openFileTab()
    try await waitUntil { harness.model.fileTabReadings[tab.id] != nil }
    harness.model.showFind()
    harness.model.setFindText("h", of: tab.id)
    let moves = harness.model.fileFindSelectionMoves(of: tab.id)
    harness.model.newShellTab()

    harness.model.setFindText("e", of: tab.id)

    #expect(harness.model.fileFindSelectionMoves(of: tab.id) == moves + 1)
  }

  @Test func closingFindForgetsWhatTheTabsViewDrewOfIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, _) = try harness.openFileTab()
    try await waitUntil { harness.model.fileTabReadings[tab.id] != nil }
    harness.model.showFind()
    harness.model.setFindText("h", of: tab.id)
    harness.model.noteFileFindShown(FileFindShown(text: "h", selectionMoves: 1), of: tab.id)

    harness.model.closeFind()

    #expect(harness.model.fileFindShown(of: tab.id) == nil)
  }
}
