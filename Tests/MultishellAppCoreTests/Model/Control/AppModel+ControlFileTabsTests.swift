import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelControlFileTabsTests {
  private static let text = FileTabRows.replacedBlock(before: 2, removed: 1, added: 2, after: 2)

  private func shownFileTab(in harness: Harness) -> FileTab {
    let tab = harness.openFileTab()
    harness.model.fileTabReadings[tab.id] = FileTabReading(
      content: .text(Self.text),
      isFileGone: false,
    )
    return tab
  }

  @Test func aFileInAWorktreeOutOfViewOpensAsATabWithoutSwitchingToIt() async throws {
    let harness = Harness()
    harness.model.select(harness.main)
    try "notes\n".write(
      to: harness.feature.path.appending(path: "notes.txt"),
      atomically: true,
      encoding: .utf8,
    )

    let reply = await harness.messageSource.ask(
      .openFileTab(worktree: ControlID.worktree(harness.feature.id), path: "notes.txt")
    )

    let tab = try #require(harness.model.workspace.fileTabs.first)
    #expect(reply?.outputFields["tab"] as? String == tab.id.uuidString)
    #expect(tab.worktreeID == harness.feature.id)
    #expect(tab.path == "notes.txt")
    #expect(harness.model.worktreeInView?.id == harness.main.id)
  }

  @Test func aFileThatWouldNotOpenAsTextIsRefusedAndOpensNoTab() async throws {
    let harness = Harness()
    try Data([0x00, 0x01]).write(to: harness.main.path.appending(path: "image.bin"))

    let reply = await harness.messageSource.ask(
      .openFileTab(worktree: ControlID.worktree(harness.main.id), path: "image.bin")
    )

    #expect(reply == .refused(.fileNotOpenable(path: "image.bin")))
    #expect(harness.model.workspace.fileTabs.isEmpty)
  }

  @Test func aStepIsQueuedForTheViewOnlyWhereTheArrowWouldBeLit() async {
    let harness = Harness()
    let tab = shownFileTab(in: harness)
    harness.model.noteChangeSteps(ChangeSteps(hasNext: true, hasPrevious: false), of: tab.id)

    let previous = await harness.messageSource.ask(
      .stepToChange(tab: tab.id, direction: .previous)
    )
    let next = await harness.messageSource.ask(.stepToChange(tab: tab.id, direction: .next))

    #expect(previous == .refused(.noChangeThatWay(id: tab.id)))
    #expect(next == .done)
    #expect(harness.model.takeChangeStepRequests(tab.id) == [.next])
  }

  @Test func aStepOnAFileTabOffScreenOrATerminalTabIsRefused() async throws {
    let harness = Harness()
    let tab = shownFileTab(in: harness)
    let terminal = try #require(harness.model.workspace.tabs.first)
    harness.model.select(harness.feature)

    let hidden = await harness.messageSource.ask(.stepToChange(tab: tab.id, direction: .next))
    let shell = await harness.messageSource.ask(
      .stepToChange(tab: terminal.id, direction: .next)
    )

    #expect(hidden == .refused(.tabNotShown(id: tab.id)))
    #expect(shell == .refused(.tabShowsNoFile(id: terminal.id)))
  }

  @Test func aFindCountsTheFilesMatchesStepsThemAndCloses() async throws {
    let harness = Harness()
    let tab = shownFileTab(in: harness)

    let opened = try #require(
      await harness.messageSource.ask(.findInFileTab(id: tab.id, action: .open("new")))
    )
    let stepped = try #require(
      await harness.messageSource.ask(.findInFileTab(id: tab.id, action: .next))
    )
    let closed = try #require(
      await harness.messageSource.ask(.findInFileTab(id: tab.id, action: .close))
    )

    let find = try #require(opened.outputFields["find"] as? [String: Any])
    #expect(find["text"] as? String == "new")
    #expect(find["total"] as? Int == 2)
    #expect(find["selected"] as? Int == 0)
    let steppedFind = try #require(stepped.outputFields["find"] as? [String: Any])
    #expect(steppedFind["selected"] as? Int == 1)
    #expect(closed.outputFields["find"] == nil)
  }

  @Test func aFindStepWithNoBarUpIsRefused() async {
    let harness = Harness()
    let tab = shownFileTab(in: harness)

    let reply = await harness.messageSource.ask(.findInFileTab(id: tab.id, action: .next))

    #expect(reply == .refused(.noFindBar(id: tab.id)))
  }

  @Test func aFindBarOverAFileTabOffScreenStillCloses() async {
    let harness = Harness()
    let tab = shownFileTab(in: harness)
    _ = await harness.messageSource.ask(.findInFileTab(id: tab.id, action: .open("new")))
    harness.model.select(harness.feature)

    let reply = await harness.messageSource.ask(.findInFileTab(id: tab.id, action: .close))

    #expect(reply?.refusal == nil)
    #expect(!harness.model.findBarTargetIDs.contains(tab.id))
  }

  @Test func aRefusedFileMakesNoBeepNobodyClickedFor() async throws {
    let harness = Harness()
    try Data([0x00]).write(to: harness.main.path.appending(path: "image.bin"))

    _ = await harness.messageSource.ask(
      .openFileTab(worktree: ControlID.worktree(harness.main.id), path: "image.bin")
    )

    #expect(harness.platform.beeps == 0)
  }

  @Test func aFileOpenedOutOfViewLeavesTheKeyboardWhereItIs() async throws {
    let harness = Harness()
    harness.model.select(harness.feature)
    harness.engine.focused = []
    try "notes\n".write(
      to: harness.main.path.appending(path: "notes.txt"),
      atomically: true,
      encoding: .utf8,
    )

    _ = await harness.messageSource.ask(
      .openFileTab(worktree: ControlID.worktree(harness.main.id), path: "notes.txt")
    )

    #expect(harness.engine.focused.isEmpty)
  }

  @Test func aFileOpenedInAWorktreeNotShownLeavesNoListingOfItKept() async throws {
    let harness = Harness()
    harness.model.select(harness.main)
    try "notes\n".write(
      to: harness.feature.path.appending(path: "notes.txt"),
      atomically: true,
      encoding: .utf8,
    )

    _ = await harness.messageSource.ask(
      .openFileTab(worktree: ControlID.worktree(harness.feature.id), path: "notes.txt")
    )

    #expect(harness.model.fileTreeCache[harness.feature.id] == nil)
  }

  @Test func aStepBeforeTheViewHasDrawnIsQueuedForIt() async {
    let harness = Harness()
    let tab = shownFileTab(in: harness)

    let reply = await harness.messageSource.ask(.stepToChange(tab: tab.id, direction: .next))

    #expect(reply == .done)
    #expect(harness.model.takeChangeStepRequests(tab.id) == [.next])
  }

  @Test func aFindOnAFileNotYetReadCountsOnceItIs() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, _) = try harness.openFileTab()
    harness.model.fileTabReadings[tab.id] = nil

    let reply = await harness.model.answer(.findInFileTab(id: tab.id, action: .open("Demo")))

    let find = try #require(reply.outputFields["find"] as? [String: Any])
    #expect(find["total"] is Int)
  }

  @Test func aFindStepBeforeTheRowsAreReadIsRefusedRatherThanLost() async {
    let harness = Harness()
    let tab = harness.openFileTab()
    _ = await harness.messageSource.ask(.findInFileTab(id: tab.id, action: .open("new")))

    let reply = await harness.messageSource.ask(.findInFileTab(id: tab.id, action: .next))

    #expect(reply == .refused(.fileTabNotRead(id: tab.id)))
  }

  @Test func aStepAfterTheTabWasHiddenWaitsForItsViewAgain() async {
    let harness = Harness()
    let tab = shownFileTab(in: harness)
    harness.model.noteChangeSteps(ChangeSteps(hasNext: false, hasPrevious: true), of: tab.id)
    harness.model.select(harness.feature)
    harness.model.releaseHiddenFileTabs()
    harness.model.select(harness.main)

    let reply = await harness.messageSource.ask(.stepToChange(tab: tab.id, direction: .next))

    #expect(reply == .done)
  }

  @Test func aFileThatWouldNotOpenLeavesNoListingOfItsWorktreeKept() async throws {
    let harness = Harness()
    harness.model.select(harness.main)
    try Data([0x00]).write(to: harness.feature.path.appending(path: "image.bin"))

    _ = await harness.messageSource.ask(
      .openFileTab(worktree: ControlID.worktree(harness.feature.id), path: "image.bin")
    )

    #expect(harness.model.fileTreeCache[harness.feature.id] == nil)
  }

  @Test func aStepWithTheMainWindowShutIsRefused() async {
    let harness = Harness()
    let tab = shownFileTab(in: harness)
    harness.platform.isWorkspaceWindowVisible = false

    let reply = await harness.messageSource.ask(.stepToChange(tab: tab.id, direction: .next))

    #expect(reply == .refused(.noWindow))
    #expect(harness.model.takeChangeStepRequests(tab.id).isEmpty)
  }

  @Test func aStepQueuedForAViewThatNeverDrewGoesWithTheTabHidden() async {
    let harness = Harness()
    let tab = shownFileTab(in: harness)
    _ = await harness.messageSource.ask(.stepToChange(tab: tab.id, direction: .next))

    harness.model.select(harness.feature)
    harness.model.releaseHiddenFileTabs()

    #expect(harness.model.takeChangeStepRequests(tab.id).isEmpty)
  }

  @Test func aSecondStepBeforeTheViewTookTheFirstIsRefused() async {
    let harness = Harness()
    let tab = shownFileTab(in: harness)
    harness.model.noteChangeSteps(ChangeSteps(hasNext: true, hasPrevious: false), of: tab.id)

    let first = await harness.messageSource.ask(.stepToChange(tab: tab.id, direction: .next))
    let second = await harness.messageSource.ask(.stepToChange(tab: tab.id, direction: .next))

    #expect(first == .done)
    #expect(second == .refused(.stepNotYetTaken(id: tab.id)))
    #expect(harness.model.takeChangeStepRequests(tab.id) == [.next])
  }
}
