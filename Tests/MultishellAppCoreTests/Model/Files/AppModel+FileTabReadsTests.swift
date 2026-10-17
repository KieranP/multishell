import Foundation
import MultishellCore
import MultishellGitKit
import TestScratch
import Testing

@testable import MultishellAppCore

@Suite(.serialized) @MainActor
struct AppModelFileTabReadsTests {
  @Test func aShownFileTabIsReadAndItsChangesFollowTheFile() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, main) = try harness.openFileTab()
    try await waitUntil { harness.model.fileTabReadings[tab.id] != nil }
    #expect(harness.model.changeKind(of: tab) == nil, "unchanged since the commit")

    try "hello\nmore\n".write(
      to: main.path.appending(path: "README.md"),
      atomically: true,
      encoding: .utf8,
    )
    harness.model.noteFileTabChanged(tab.id)

    try await waitUntil { harness.model.changeKind(of: tab) == .modified }
    #expect(harness.model.changeKind(of: tab) == .modified)
  }

  @Test func aHiddenTabIsOwedItsReadButADeletionStrikesItAtOnce() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, main) = try harness.openFileTab()
    try await waitUntil { harness.model.fileTabReadings[tab.id] != nil }
    harness.model.newShellTab()

    try FileManager.default.removeItem(at: main.path.appending(path: "README.md"))
    harness.model.noteFileTabChanged(tab.id)

    try await waitUntil { harness.model.fileIsGone(of: tab.id) }
    #expect(harness.model.fileIsGone(of: tab.id))
    #expect(harness.model.fileTabReadLog.owed.contains(tab.id))
  }

  @Test func aHiddenTabWhoseFileComesBackLosesItsStrike() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, main) = try harness.openFileTab()
    try await waitUntil { harness.model.fileTabReadings[tab.id] != nil }
    harness.model.newShellTab()
    let readme = main.path.appending(path: "README.md")
    let text = try String(contentsOf: readme, encoding: .utf8)
    try FileManager.default.removeItem(at: readme)
    harness.model.noteFileTabChanged(tab.id)
    try await waitUntil { harness.model.fileIsGone(of: tab.id) }

    try text.write(to: readme, atomically: true, encoding: .utf8)
    harness.model.noteFileTabChanged(tab.id)

    try await waitUntil { !harness.model.fileIsGone(of: tab.id) }
    #expect(!harness.model.fileIsGone(of: tab.id))
  }

  @Test func aTabNeverShownSinceLaunchIsStruckWhenItsFileGoes() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let other = try await harness.createWorktree(onBranch: "other")
    harness.model.select(try #require(harness.worktree(onBranch: "main")))
    let tab = try #require(harness.store.openFileTab(path: "README.md", in: other.id))

    try FileManager.default.removeItem(at: other.path.appending(path: "README.md"))
    harness.model.noteFileTabChanged(tab.id)

    try await waitUntil { harness.model.fileIsGone(of: tab.id) }
    #expect(harness.model.fileIsGone(of: tab.id))
  }

  @Test func everythingKeptForAClosedTabGoesWithIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, _) = try harness.openFileTab()
    try await waitUntil { harness.model.fileTabReadings[tab.id] != nil }

    harness.model.noteFileTabSelection("hello", of: tab.id)
    harness.model.showFind()
    harness.model.setFindText("hello", of: tab.id)
    #expect(harness.model.fileFindResults[tab.id] != nil)
    harness.model.noteFileFindShown(FileFindShown(text: "hello", selectionMoves: 1), of: tab.id)
    harness.model.noteFileTabScrolled(
      tab.id,
      to: FileTabScroll(line: 0, isHEADsLine: false, rowsFromLine: 40, x: 0),
    )
    #expect(
      harness.model.fileTabScroll(of: tab.id)
        == FileTabScroll(line: 0, isHEADsLine: false, rowsFromLine: 40, x: 0)
    )

    harness.model.closeTab(tab.id)

    #expect(harness.model.fileTabReadings[tab.id] == nil)
    #expect(harness.model.fileTabSelections[tab.id] == nil)
    #expect(harness.model.fileFindShown(of: tab.id) == nil)
    #expect(harness.model.fileTabScroll(of: tab.id) == nil)
    #expect(harness.model.fileFindResults[tab.id] == nil)
    #expect(harness.model.findTexts[tab.id] == nil)
    #expect(!harness.model.fileTabReadLog.owed.contains(tab.id))
    #expect(harness.model.pendingFileTabReads[tab.id] == nil)
  }

  @Test func aReconcileDuringTheFirstReadAsksForNoSecond() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, _) = try harness.openFileTab()
    var turns = 0
    while !harness.model.fileTabReadLog.isReading(tab.id), turns < 100_000 {
      await Task.yield()
      turns += 1
    }
    #expect(harness.model.fileTabReadLog.isReading(tab.id))

    harness.model.reconcileSessions(takingFocus: false)
    try await waitUntil { harness.model.fileTabReadings[tab.id] != nil }

    #expect(harness.model.pendingFileTabReads[tab.id] == nil)
  }

  @Test func aDeletedFilesHiddenTabKeepsHeadsTextWhenItComesBackAndGoesAgain() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    let readme = main.path.appending(path: "README.md")
    let text = try String(contentsOf: readme, encoding: .utf8)
    try FileManager.default.removeItem(at: readme)
    let (tab, _) = try harness.openFileTab()
    try await waitUntil { harness.model.fileTabReadings[tab.id] != nil }
    harness.model.newShellTab()
    try text.write(to: readme, atomically: true, encoding: .utf8)
    harness.model.noteFileTabChanged(tab.id)
    try await waitUntil { !harness.model.fileIsGone(of: tab.id) }
    try FileManager.default.removeItem(at: readme)
    harness.model.noteFileTabChanged(tab.id)
    try await waitUntil { harness.model.fileIsGone(of: tab.id) }

    harness.model.activateTab(tab.id)

    let rows = try #require(await harness.rowsArrive(in: tab.id))
    #expect(!rows.lines.isEmpty)
  }

  @Test func aTabShownAgainWhileItsReadRunsGetsTheReadItWasOwed() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, _) = try harness.openFileTab()
    try await waitUntil { harness.model.fileTabReadings[tab.id] != nil }
    try await waitUntil { harness.model.pendingFileTabReads[tab.id] == nil }
    let log = { harness.model.fileTabReadLog }
    harness.model.noteFileTabChanged(tab.id)
    var turns = 0
    while !log().isReading(tab.id), turns < 1_000_000 {
      await Task.yield()
      turns += 1
    }
    harness.model.newShellTab()
    harness.model.noteFileTabChanged(tab.id)
    harness.model.activateTab(tab.id)
    #expect(log().isReading(tab.id))

    try await waitUntil {
      !log().isReading(tab.id) && harness.model.pendingFileTabReads[tab.id] == nil
        && !log().owed.contains(tab.id)
    }
    #expect(!log().owed.contains(tab.id))
  }

  @Test func aReadRunningAsAHiddenTabsFileGoesLeavesTheTabStruck() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, main) = try harness.openFileTab()
    try await waitUntil { harness.model.fileTabReadings[tab.id] != nil }
    try await waitUntil { harness.model.pendingFileTabReads[tab.id] == nil }
    let log = { harness.model.fileTabReadLog }
    harness.model.noteFileTabChanged(tab.id)
    var turns = 0
    while !log().isReading(tab.id), turns < 1_000_000 {
      await Task.yield()
      turns += 1
    }
    harness.model.newShellTab()
    try FileManager.default.removeItem(at: main.path.appending(path: "README.md"))

    harness.model.noteFileTabChanged(tab.id)

    try await waitUntil { !log().isReading(tab.id) && harness.model.fileIsGone(of: tab.id) }
    #expect(harness.model.fileIsGone(of: tab.id))
  }

  @Test func aHiddenTabLetsGoOfItsRowsAndKeepsItsDot() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, main) = try harness.openFileTab()
    try "hello\nmore\n".write(
      to: main.path.appending(path: "README.md"),
      atomically: true,
      encoding: .utf8,
    )
    harness.model.noteFileTabChanged(tab.id)
    try await waitUntil { harness.model.changeKind(of: tab) == .modified }

    harness.model.newShellTab()

    #expect(harness.model.fileTabReadings[tab.id]?.content == .released(changeKind: .modified))
    #expect(harness.model.changeKind(of: tab) == .modified)
  }

  @Test func aTabShownAgainIsReadAtOnceWhateverItsPace() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, _) = try harness.openFileTab()
    try await waitUntil { harness.model.fileTabReadings[tab.id] != nil }
    try await waitUntil { harness.model.pendingFileTabReads[tab.id] == nil }
    harness.model.fileTabReadLog.noteHighlightCost(.seconds(30), of: tab.id)
    harness.model.newShellTab()

    harness.model.activateTab(tab.id)

    #expect(try await harness.rowsArrive(in: tab.id) != nil)
  }

  @Test func aReadWaitingWhenItsTabIsHiddenIsOwedRatherThanRun() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, main) = try harness.openFileTab()
    try await waitUntil { harness.model.fileTabReadings[tab.id] != nil }
    try await waitUntil { harness.model.pendingFileTabReads[tab.id] == nil }
    try "hello\nmore\n".write(
      to: main.path.appending(path: "README.md"),
      atomically: true,
      encoding: .utf8,
    )
    harness.model.noteFileTabChanged(tab.id)
    #expect(harness.model.pendingFileTabReads[tab.id] != nil)

    harness.model.newShellTab()

    #expect(harness.model.pendingFileTabReads[tab.id] == nil)
    #expect(harness.model.fileTabReadLog.owed.contains(tab.id))
    #expect(harness.model.fileTabReadings[tab.id]?.content == .released(changeKind: nil))
  }

  @Test func aTabWhoseFileIsGoneKeepsTheTextItLastReadWhenHidden() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, main) = try harness.openFileTab()
    let readme = main.path.appending(path: "README.md")
    try "edited\n".write(to: readme, atomically: true, encoding: .utf8)
    harness.model.noteFileTabChanged(tab.id)
    try await waitUntil { harness.model.changeKind(of: tab) == .modified }
    try FileManager.default.removeItem(at: readme)
    harness.model.noteFileTabChanged(tab.id)
    try await waitUntil { harness.model.fileIsGone(of: tab.id) }

    harness.model.newShellTab()
    harness.model.activateTab(tab.id)
    await harness.model.readFileTab(tab.id)

    guard case .text(let rows) = harness.model.fileTabReadings[tab.id]?.content else {
      Issue.record("no rows")
      return
    }
    #expect(rows.lines.map(\.text) == ["edited"])
  }

  @Test func closingTheBoardReadsTheTabInFrontAgain() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, _) = try harness.openFileTab()
    try await waitUntil { harness.model.fileTabReadings[tab.id] != nil }
    try await waitUntil { harness.model.pendingFileTabReads[tab.id] == nil }
    harness.model.toggleAgentBoard()
    harness.model.reconcileSessions(takingFocus: false)

    harness.model.toggleAgentBoard()

    #expect(try await harness.rowsArrive(in: tab.id) != nil)
  }

  @Test func aTabShownAgainIsNotKeptWaitingByAPacedReadAlreadyPending() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, main) = try harness.openFileTab()
    try await waitUntil { harness.model.fileTabReadings[tab.id] != nil }
    try await waitUntil { harness.model.pendingFileTabReads[tab.id] == nil }
    harness.model.fileTabReadLog.noteHighlightCost(.seconds(30), of: tab.id)
    try "hello\nmore\n".write(
      to: main.path.appending(path: "README.md"),
      atomically: true,
      encoding: .utf8,
    )
    harness.model.noteFileTabChanged(tab.id)
    harness.model.newShellTab()

    harness.model.activateTab(tab.id)

    #expect(try await harness.rowsArrive(in: tab.id) != nil)
  }

  @Test func choosingAnotherWorktreeFromTheBoardReadsNoneOfTheOldOnesTabs() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let other = try await harness.createWorktree(onBranch: "other")
    let (tab, _) = try harness.openFileTab()
    try await waitUntil { harness.model.fileTabReadings[tab.id] != nil }
    try await waitUntil { harness.model.pendingFileTabReads[tab.id] == nil }
    harness.model.toggleAgentBoard()
    harness.model.reconcileSessions(takingFocus: false)

    harness.model.select(other)

    #expect(harness.model.pendingFileTabReads[tab.id] == nil)
    #expect(!harness.model.fileTabReadLog.isReading(tab.id))
  }

  @Test func aHiddenTabWhoseFileComesBackLetsGoOfTheRowsItKept() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, main) = try harness.openFileTab()
    let readme = main.path.appending(path: "README.md")
    let text = try String(contentsOf: readme, encoding: .utf8)
    try await waitUntil { harness.model.fileTabReadings[tab.id] != nil }
    try FileManager.default.removeItem(at: readme)
    harness.model.noteFileTabChanged(tab.id)
    try await waitUntil { harness.model.fileIsGone(of: tab.id) }
    harness.model.newShellTab()
    try text.write(to: readme, atomically: true, encoding: .utf8)

    harness.model.noteFileTabChanged(tab.id)

    try await waitUntil { !harness.model.fileIsGone(of: tab.id) }
    #expect(harness.model.fileTabReadings[tab.id]?.content == .releasedFollowingStatus)
  }

  @Test func aHiddenTabWhoseFileComesBackEditedShowsTheStatusDot() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, main) = try harness.openFileTab()
    let readme = main.path.appending(path: "README.md")
    try await waitUntil { harness.model.fileTabReadings[tab.id] != nil }
    try FileManager.default.removeItem(at: readme)
    harness.model.noteFileTabChanged(tab.id)
    try await waitUntil { harness.model.fileIsGone(of: tab.id) }
    harness.model.newShellTab()
    try "edited\n".write(to: readme, atomically: true, encoding: .utf8)
    _ = await harness.model.refreshStatus(of: main.id, forced: true)

    harness.model.noteFileTabChanged(tab.id)

    try await waitUntil { !harness.model.fileIsGone(of: tab.id) }
    #expect(harness.model.changeKind(of: tab) == .modified)
  }

  @Test func aHiddenTabWhoseFileComesBackTakesItsDotFromTheStatusReadAfter() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, main) = try harness.openFileTab()
    let readme = main.path.appending(path: "README.md")
    try await waitUntil { harness.model.fileTabReadings[tab.id] != nil }
    try FileManager.default.removeItem(at: readme)
    harness.model.noteFileTabChanged(tab.id)
    try await waitUntil { harness.model.fileIsGone(of: tab.id) }
    _ = await harness.model.refreshStatus(of: main.id, forced: true)
    harness.model.newShellTab()
    try "edited\n".write(to: readme, atomically: true, encoding: .utf8)

    harness.model.noteFileTabChanged(tab.id)
    try await waitUntil { !harness.model.fileIsGone(of: tab.id) }
    _ = await harness.model.refreshStatus(of: main.id, forced: true)

    #expect(harness.model.changeKind(of: tab) == .modified)
  }
}
