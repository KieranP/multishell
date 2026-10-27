import Foundation
import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite @MainActor
struct AppModelQuickSwitcherTests {
  @Test func itsOwnKeyAgainClosesItAndTheOtherKeyChangesItsScope() {
    let model = Harness().model

    model.toggleQuickSwitcher(.all)
    #expect(model.quickSwitcher?.scope == .all)

    model.toggleQuickSwitcher(.commands)
    #expect(model.quickSwitcher?.scope == .commands)

    model.toggleQuickSwitcher(.commands)
    #expect(model.quickSwitcher == nil)
  }

  @Test func tabStepsThroughEveryScopeAndWrapsAtEitherEnd() {
    let model = Harness().model
    model.toggleQuickSwitcher(.all)
    var stepped: [QuickSwitcherScope] = []

    for _ in 0..<6 {
      model.stepQuickSwitcherScope(.next)
      stepped.append(model.quickSwitcher?.scope ?? .all)
    }
    model.stepQuickSwitcherScope(.previous)

    #expect(stepped == [.agents, .worktrees, .tabs, .files, .commands, .all])
    #expect(model.quickSwitcher?.scope == .commands)
  }

  @Test func theFieldLosingTheKeyboardClosesItAndLeavesTheKeyboardWhereItWent() {
    let (harness, _) = Harness.withOnePane()
    harness.model.toggleQuickSwitcher(.all)
    let focusesBefore = harness.engine.focused.count

    harness.model.noteQuickSwitcherFieldEndedEditing()

    #expect(harness.model.quickSwitcher == nil)
    #expect(harness.engine.focused.count == focusesBefore)
  }

  @Test func anythingElseHandingAPaneTheKeyboardClosesIt() {
    let (harness, _) = Harness.withOnePane()
    harness.model.toggleQuickSwitcher(.all)

    harness.model.newTab()

    #expect(harness.model.quickSwitcher == nil)
  }

  @Test func anItemSharingItsTitlesWithAGreyedOutOneBeforeItIsNotListed() {
    let harness = Harness()
    harness.platform.menuItems = [
      PlatformMenuItem(path: ["Window", "Foo"], isEnabled: false, isChecked: false),
      PlatformMenuItem(path: ["Window", "Foo"], isEnabled: true, isChecked: false),
    ]

    harness.model.toggleQuickSwitcher(.commands)

    #expect(harness.model.quickSwitcherResults.rows == [])
  }

  @Test func choosingAFileOpensItThenLetsGoOfTheListing() async throws {
    let harness = Harness()
    harness.model.select(harness.main)
    try Data("hello\n".utf8).write(to: harness.main.path.appendingPathComponent("notes.txt"))
    harness.model.toggleQuickSwitcher(.files)
    harness.model.trackedFiles[harness.main.id] = TrackedFiles(
      paths: ["notes.txt"],
      submodulePaths: [],
      notCheckedOutPaths: [],
      isCapped: false,
    )

    harness.model.chooseQuickSwitcherRow(.file(path: "notes.txt", worktreeID: harness.main.id))
    try await waitUntil { harness.model.workspace.fileTabs.contains { $0.path == "notes.txt" } }
    await harness.settled()

    #expect(harness.model.trackedFiles[harness.main.id] == nil)
    #expect(harness.model.fileTreeCache[harness.main.id] == nil)
  }

  @Test func choosingAFileOverTheAgentsBoardTakesTheBoardDown() async throws {
    let harness = Harness()
    harness.model.select(harness.main)
    try Data("hello\n".utf8).write(to: harness.main.path.appendingPathComponent("notes.txt"))
    harness.model.trackedFiles[harness.main.id] = TrackedFiles(
      paths: ["notes.txt"],
      submodulePaths: [],
      notCheckedOutPaths: [],
      isCapped: false,
    )
    harness.model.showAgentBoard()
    harness.model.toggleQuickSwitcher(.files)

    harness.model.chooseQuickSwitcherRow(.file(path: "notes.txt", worktreeID: harness.main.id))
    try await waitUntil { harness.model.workspace.fileTabs.contains { $0.path == "notes.txt" } }

    #expect(!harness.model.showsAgentBoard)
  }

  @Test func choosingAFileInAWorktreeWithNoTabsOpensOnlyTheFile() async throws {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.closeActiveTab()
    try #require(harness.model.workspace.tabs(in: harness.main.id).isEmpty)
    try Data("hello\n".utf8).write(to: harness.main.path.appendingPathComponent("notes.txt"))
    harness.model.trackedFiles[harness.main.id] = TrackedFiles(
      paths: ["notes.txt"],
      submodulePaths: [],
      notCheckedOutPaths: [],
      isCapped: false,
    )
    harness.model.toggleQuickSwitcher(.files)

    harness.model.chooseQuickSwitcherRow(.file(path: "notes.txt", worktreeID: harness.main.id))
    try await waitUntil { harness.model.workspace.fileTabs.contains { $0.path == "notes.txt" } }

    #expect(harness.model.workspace.tabs(in: harness.main.id).isEmpty)
  }

  @Test func aSymlinkedFileOpenedOverTheAgentsBoardTakesItDown() async throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let root = harness.main.path
    try Data("guide\n".utf8).write(to: root.appendingPathComponent("GUIDE.md"))
    try FileManager.default.createDirectory(
      at: root.appendingPathComponent("docs"),
      withIntermediateDirectories: true,
    )
    try FileManager.default.createSymbolicLink(
      atPath: root.appendingPathComponent("docs/guide.md").path,
      withDestinationPath: "../GUIDE.md",
    )
    harness.model.trackedFiles[harness.main.id] = TrackedFiles(
      paths: ["GUIDE.md", "docs/guide.md"],
      submodulePaths: [],
      notCheckedOutPaths: [],
      isCapped: false,
    )
    harness.model.showAgentBoard()
    harness.model.toggleQuickSwitcher(.files)

    harness.model.chooseQuickSwitcherRow(.file(path: "docs/guide.md", worktreeID: harness.main.id))
    try await waitUntil { !harness.model.workspace.fileTabs.isEmpty }
    await harness.settled()

    #expect(!harness.model.showsAgentBoard)
  }

  @Test func aCoverRaisedAfterAFileIsChosenStaysUpOnceItOpens() async throws {
    let harness = Harness()
    harness.model.select(harness.main)
    try Data("hello\n".utf8).write(to: harness.main.path.appendingPathComponent("notes.txt"))
    harness.model.trackedFiles[harness.main.id] = TrackedFiles(
      paths: ["notes.txt"],
      submodulePaths: [],
      notCheckedOutPaths: [],
      isCapped: false,
    )
    harness.model.toggleQuickSwitcher(.files)

    harness.model.chooseQuickSwitcherRow(.file(path: "notes.txt", worktreeID: harness.main.id))
    harness.model.showAgentBoard()
    try await waitUntil { harness.model.workspace.fileTabs.contains { $0.path == "notes.txt" } }
    await harness.settled()

    #expect(harness.model.showsAgentBoard)
  }

  @Test func aFileThatWillNotOpenLeavesTheAgentsBoardUp() async throws {
    let harness = Harness()
    harness.model.select(harness.main)
    try Data([0, 1, 2]).write(to: harness.main.path.appendingPathComponent("image.bin"))
    harness.model.trackedFiles[harness.main.id] = TrackedFiles(
      paths: ["image.bin"],
      submodulePaths: [],
      notCheckedOutPaths: [],
      isCapped: false,
    )
    harness.model.showAgentBoard()
    harness.model.toggleQuickSwitcher(.files)

    harness.model.chooseQuickSwitcherRow(.file(path: "image.bin", worktreeID: harness.main.id))
    try await waitUntil { harness.platform.beeps == 1 }
    await harness.settled()

    #expect(harness.model.showsAgentBoard)
  }

  @Test func closingOverACoverLetsGoOfTheListingThoughThePanelIsOn() {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.setShowsFilesPanel(true)
    harness.model.showAgentBoard()
    harness.model.toggleQuickSwitcher(.files)
    harness.model.trackedFiles[harness.main.id] = .empty

    harness.model.closeQuickSwitcher()

    #expect(harness.model.trackedFiles[harness.main.id] == nil)
  }

  @Test func aKeptFileSearchGoesWithTheListingItRanOver() {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.trackedFiles[harness.main.id] = TrackedFiles(
      paths: ["src/main.swift"],
      submodulePaths: [],
      notCheckedOutPaths: [],
      isCapped: false,
    )
    harness.model.toggleQuickSwitcher(.files)
    harness.model.setQuickSwitcherText("main")
    _ = harness.model.quickSwitcherResults

    harness.model.forgetPanelListings { _ in true }

    #expect(harness.model.fileTreeCache[harness.main.id]?.quickSwitcherSearch == nil)
  }

  @Test func anItemAndItsNameWithAnEllipsisAreOneCommand() {
    let harness = Harness()
    harness.platform.menuItems = [
      PlatformMenuItem(path: ["File", "Export"], isEnabled: true, isChecked: false),
      PlatformMenuItem(path: ["File", "Export…"], isEnabled: true, isChecked: false),
    ]

    harness.model.toggleQuickSwitcher(.commands)

    #expect(harness.model.quickSwitcherResults.rows == [.command(path: ["File", "Export"])])
  }

  @Test func shuttingTheFilesPanelWhileItIsUpKeepsTheListingUntilItCloses() {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.setShowsFilesPanel(true)
    harness.model.trackedFiles[harness.main.id] = .empty
    harness.model.toggleQuickSwitcher(.files)

    harness.model.setShowsFilesPanel(false)
    #expect(harness.model.trackedFiles[harness.main.id] == .empty)

    harness.model.closeQuickSwitcher()
    #expect(harness.model.trackedFiles[harness.main.id] == nil)
  }

  @Test func menuItemsSharingTheirTitlesAreListedOnce() {
    let harness = Harness()
    let item = PlatformMenuItem(path: ["Window", "Multishell"], isEnabled: true, isChecked: false)
    harness.platform.menuItems = [item, item]

    harness.model.toggleQuickSwitcher(.commands)

    #expect(harness.model.quickSwitcherResults.rows == [.command(path: ["Window", "Multishell"])])
  }

  @Test func itDoesNotOpenOverAnotherWindow() {
    let harness = Harness()
    harness.platform.isWorkspaceWindowKey = false

    harness.model.toggleQuickSwitcher(.all)

    #expect(harness.model.quickSwitcher == nil)
  }

  @Test func aGreaterThanSignTypedFirstTurnsAllToCommandsAndIsDropped() {
    let model = Harness().model
    model.toggleQuickSwitcher(.all)

    model.setQuickSwitcherText(">split")

    #expect(model.quickSwitcher?.scope == .commands)
    #expect(model.quickSwitcher?.text == "split")
  }

  @Test func aGreaterThanSignCarriedIntoAllByTabStaysText() {
    let model = Harness().model
    model.toggleQuickSwitcher(.commands)
    model.setQuickSwitcherText(">")
    model.stepQuickSwitcherScope(.next)

    model.setQuickSwitcherText(">g")

    #expect(model.quickSwitcher?.scope == .all)
    #expect(model.quickSwitcher?.text == ">g")
  }

  @Test func backspaceInAnEmptyFieldGoesBackToAll() {
    let model = Harness().model
    model.toggleQuickSwitcher(.all)
    model.setQuickSwitcherText(">")

    model.backspaceInEmptyQuickSwitcherField()

    #expect(model.quickSwitcher?.scope == .all)
  }

  @Test func closingItHandsTheKeyboardBackToThePane() {
    let (harness, session) = Harness.withOnePane()
    harness.model.toggleQuickSwitcher(.all)
    let focusesBefore = harness.engine.focused.count

    harness.model.closeQuickSwitcher()

    #expect(harness.model.quickSwitcher == nil)
    #expect(harness.engine.focused.count == focusesBefore + 1)
    #expect(harness.engine.focused.last == session.id)
  }

  @Test func choosingAWorktreeSelectsItAndCloses() {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.toggleQuickSwitcher(.worktrees)

    harness.model.chooseQuickSwitcherRow(.worktree(harness.feature.id))

    #expect(harness.model.workspace.selectedWorktreeID == harness.feature.id)
    #expect(harness.model.quickSwitcher == nil)
  }

  @Test func choosingAProjectSelectsTheWorktreeTurnedToLast() {
    let harness = Harness()
    harness.model.select(harness.feature)
    harness.model.toggleQuickSwitcher(.all)

    harness.model.chooseQuickSwitcherRow(.project(harness.project.id))

    #expect(harness.model.workspace.selectedWorktreeID == harness.feature.id)
  }

  @Test func choosingAProjectNeverTurnedToSelectsItsMainWorktree() {
    let harness = Harness()
    harness.model.toggleQuickSwitcher(.all)

    harness.model.chooseQuickSwitcherRow(.project(harness.project.id))

    #expect(harness.model.workspace.selectedWorktreeID == harness.main.id)
  }

  @Test func choosingAPaneInAnotherWorktreeSelectsThatWorktreeAndFocusesThePane() throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let mainPane = try #require(harness.model.workspace.sessions(in: harness.main.id).first)
    harness.model.select(harness.feature)
    harness.model.toggleQuickSwitcher(.tabs)

    harness.model.chooseQuickSwitcherRow(.pane(mainPane.id))

    #expect(harness.model.workspace.selectedWorktreeID == harness.main.id)
    #expect(harness.engine.focused.last == mainPane.id)
  }

  @Test func choosingAFileTabSelectsItsWorktreeAndShowsIt() {
    let harness = Harness()
    let fileTab = harness.openFileTab()
    harness.model.select(harness.feature)
    harness.model.toggleQuickSwitcher(.tabs)

    harness.model.chooseQuickSwitcherRow(.fileTab(fileTab.id))

    #expect(harness.model.workspace.selectedWorktreeID == harness.main.id)
    #expect(harness.model.workspace.activeWorkspaceTab(in: harness.main.id)?.id == fileTab.id)
  }

  @Test func choosingACommandHandsItsMenuItemOverAsTheUsersClickNotTheCommandLines() {
    let harness = Harness()
    harness.platform.menuItems = [
      PlatformMenuItem(path: ["Edit", "Paste"], isEnabled: true, isChecked: false)
    ]
    harness.model.toggleQuickSwitcher(.commands)

    harness.model.chooseQuickSwitcherRow(.command(path: ["Edit", "Paste"]))

    #expect(harness.platform.chosenMenuItems == [["Edit", "Paste"]])
    #expect(harness.platform.performedMenuItems == [])
  }

  @Test func choosingAPaneThatHasGoneHandsTheKeyboardBackToThePaneInView() {
    let (harness, session) = Harness.withOnePane()
    harness.model.toggleQuickSwitcher(.tabs)
    let focusesBefore = harness.engine.focused.count

    harness.model.chooseQuickSwitcherRow(.pane(TerminalSession.ID()))

    #expect(harness.model.quickSwitcher == nil)
    #expect(harness.engine.focused.count == focusesBefore + 1)
    #expect(harness.engine.focused.last == session.id)
  }

  @Test func choosingAFileTabThatHasGoneHandsTheKeyboardBackToThePaneInView() {
    let (harness, session) = Harness.withOnePane()
    harness.model.toggleQuickSwitcher(.tabs)
    let focusesBefore = harness.engine.focused.count

    harness.model.chooseQuickSwitcherRow(.fileTab(FileTab.ID()))

    #expect(harness.engine.focused.count == focusesBefore + 1)
    #expect(harness.engine.focused.last == session.id)
  }

  @Test func theArrowsMoveTheSelectionStoppingAtEitherEndAndReturnChoosesIt() {
    let harness = Harness()
    harness.model.toggleQuickSwitcher(.worktrees)
    #expect(harness.model.quickSwitcherResults.selection == .worktree(harness.main.id))

    harness.model.moveQuickSwitcherSelection(.next)
    harness.model.moveQuickSwitcherSelection(.next)
    #expect(harness.model.quickSwitcherResults.selection == .worktree(harness.feature.id))

    harness.model.moveQuickSwitcherSelection(.previous)
    harness.model.moveQuickSwitcherSelection(.previous)
    #expect(harness.model.quickSwitcherResults.selection == .worktree(harness.main.id))

    harness.model.moveQuickSwitcherSelection(.next)
    harness.model.chooseSelectedQuickSwitcherRow()
    #expect(harness.model.workspace.selectedWorktreeID == harness.feature.id)
  }

  @Test func onlyTheArrowsCountAsArrowPresses() {
    let harness = Harness()
    harness.model.toggleQuickSwitcher(.worktrees)

    harness.model.setQuickSwitcherText("a")
    #expect(harness.model.quickSwitcherResults.arrowPresses == 0)

    harness.model.moveQuickSwitcherSelection(.next)
    #expect(harness.model.quickSwitcherResults.arrowPresses == 1)
  }

  @Test func aSelectedRowForgottenOnceGoneIsNotSelectedAgainWhenItComesBack() {
    let harness = Harness()
    harness.model.toggleQuickSwitcher(.worktrees)
    harness.model.moveQuickSwitcherSelection(.next)
    #expect(harness.model.quickSwitcherResults.selection == .worktree(harness.feature.id))
    harness.store.replaceWorktrees([harness.main], forProject: harness.project.id)

    harness.model.forgetLostQuickSwitcherSelection()
    harness.store.replaceWorktrees(
      [harness.main, harness.feature],
      forProject: harness.project.id,
    )

    #expect(harness.model.quickSwitcherResults.selection == .worktree(harness.main.id))
  }

  @Test func thePointerOverARowSelectsItWithoutCountingAsTheArrows() {
    let harness = Harness()
    harness.model.toggleQuickSwitcher(.worktrees)

    harness.model.pointQuickSwitcherAt(.worktree(harness.feature.id))

    let results = harness.model.quickSwitcherResults
    #expect(results.selection == .worktree(harness.feature.id))
    #expect(results.arrowPresses == 0)
    harness.model.chooseSelectedQuickSwitcherRow()
    #expect(harness.model.workspace.selectedWorktreeID == harness.feature.id)
  }

  @Test func theArrowsMoveOnFromTheRowThePointerSelected() {
    let harness = Harness()
    harness.model.toggleQuickSwitcher(.worktrees)
    harness.model.pointQuickSwitcherAt(.worktree(harness.feature.id))

    harness.model.moveQuickSwitcherSelection(.previous)

    #expect(harness.model.quickSwitcherResults.selection == .worktree(harness.main.id))
    #expect(harness.model.quickSwitcherResults.arrowPresses == 1)
  }

  @Test func theAppMenusCommandsReadAsTheApplicationsNotByTheAppsName() throws {
    let harness = Harness()
    harness.platform.menuItems = [
      PlatformMenuItem(
        path: ["Multishell", "Settings…"],
        isEnabled: true,
        isChecked: false,
        isInAppMenu: true,
      )
    ]

    harness.model.toggleQuickSwitcher(.commands)

    let row = try #require(harness.model.quickSwitcherResults.sections.first?.items.first)
    #expect(row.location == t("command.application"))
  }

  @Test(arguments: ["worktree", "pane", "file tab"])
  func choosingAPlaceInACollapsedProjectOpensItInTheSidebar(_ kind: String) throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = try #require(harness.model.workspace.activeTab(in: harness.main.id))
    harness.store.openFileTab(path: "notes.md", in: harness.main.id)
    let fileTab = try #require(harness.model.workspace.fileTabs.first)
    harness.store.setExpanded(false, forProject: harness.project.id)
    harness.model.toggleQuickSwitcher(.all)
    let targets: [String: QuickSwitcherTarget] = [
      "worktree": .worktree(harness.feature.id),
      "pane": .pane(tab.focusedSessionID),
      "file tab": .fileTab(fileTab.id),
    ]

    harness.model.chooseQuickSwitcherRow(try #require(targets[kind]))

    #expect(harness.model.workspace.project(harness.project.id)?.isExpanded == true)
  }

  @Test func aFileTheOpenRefusesLeavesItsCollapsedProjectAsItWas() async throws {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.store.setExpanded(false, forProject: harness.project.id)
    harness.model.toggleQuickSwitcher(.files)

    harness.model.chooseQuickSwitcherRow(.file(path: "missing.md", worktreeID: harness.main.id))
    try await waitUntil { harness.platform.beeps == 1 }

    #expect(harness.model.workspace.project(harness.project.id)?.isExpanded == false)
  }

  @Test func choosingAWorktreeTheSidebarFilterHidesClearsTheFilterSoItsRowShows() {
    let harness = Harness()
    harness.model.sidebarFilterText = "matches-no-row"
    harness.model.toggleQuickSwitcher(.worktrees)

    harness.model.chooseQuickSwitcherRow(.worktree(harness.feature.id))

    let shown = harness.model.sidebarEntries.flatMap(\.worktrees).map(\.id)
    #expect(shown.contains(harness.feature.id))
  }

  @Test func choosingAProjectWithNoWorktreesBeeps() {
    let harness = Harness()
    harness.store.replaceWorktrees([], forProject: harness.project.id)
    harness.model.toggleQuickSwitcher(.all)

    harness.model.chooseQuickSwitcherRow(.project(harness.project.id))

    #expect(harness.platform.beeps == 1)
  }

  @Test(arguments: [
    QuickSwitcherTarget.pane(UUID()),
    .fileTab(UUID()),
    .worktree("/gone"),
  ])
  func choosingARowWhoseTargetHasGoneBeepsAsAGoneProjectDoes(target: QuickSwitcherTarget) {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.toggleQuickSwitcher(.all)

    harness.model.chooseQuickSwitcherRow(target)

    #expect(harness.platform.beeps == 1)
  }

  @Test func typingPutsTheSelectionBackOnTheFirstRow() {
    let harness = Harness()
    harness.model.toggleQuickSwitcher(.worktrees)
    harness.model.moveQuickSwitcherSelection(.next)

    harness.model.setQuickSwitcherText("ma")

    #expect(harness.model.quickSwitcherResults.selection == .worktree(harness.main.id))
  }

  @Test func closingLetsGoOfTheFileListingItReadWhileThePanelIsShut() {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.toggleQuickSwitcher(.files)
    harness.model.trackedFiles[harness.main.id] = .empty

    harness.model.closeQuickSwitcher()

    #expect(harness.model.trackedFiles[harness.main.id] == nil)
  }

  @Test func closingKeepsTheListingAShownPanelReads() {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.setShowsFilesPanel(true)
    harness.model.trackedFiles[harness.main.id] = .empty
    harness.model.toggleQuickSwitcher(.files)

    harness.model.closeQuickSwitcher()

    #expect(harness.model.trackedFiles[harness.main.id] == .empty)
  }
}
