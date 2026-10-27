import Foundation
import MultishellCore
import Observation
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite @MainActor
struct AppModelQuickSwitcherSectionsTests {
  private static func kinds(_ model: AppModel<FakeSurface>) -> [QuickSwitcherSection.Kind] {
    model.quickSwitcherResults.sections.map(\.kind)
  }

  private static func targets(
    _ model: AppModel<FakeSurface>,
    in kind: QuickSwitcherSection.Kind,
  ) -> [QuickSwitcherTarget] {
    model.quickSwitcherResults.sections.first { $0.kind == kind }?.items.map(\.target) ?? []
  }

  private static func tracked(_ paths: [String]) -> TrackedFiles {
    TrackedFiles(paths: paths, submodulePaths: [], notCheckedOutPaths: [], isCapped: false)
  }

  @Test func emptyItListsWaitingAgentsLongestWaitFirstThenRecentWorktrees() throws {
    let harness = Harness()
    harness.model.select(harness.feature)
    let first = harness.openBackgroundTab()
    let second = try #require(harness.model.workspace.activeTab(in: harness.main.id))
    for tab in [second, first] {
      harness.messageSource.send(
        SessionStateReport(state: .attention, sessionID: tab.focusedSessionID, agentID: "claude")
      )
    }

    harness.model.toggleQuickSwitcher(.all)

    #expect(Self.kinds(harness.model) == [.waiting, .recent])
    #expect(
      Self.targets(harness.model, in: .waiting)
        == [.pane(second.focusedSessionID), .pane(first.focusedSessionID)]
    )
    #expect(Self.targets(harness.model, in: .recent) == [.worktree(harness.feature.id)])
  }

  @Test func theSelectedWorktreeIsRecentWhileACoverHidesIt() {
    let harness = Harness()
    harness.model.select(harness.feature)
    harness.model.select(harness.main)
    harness.model.showAgentBoard()

    harness.model.toggleQuickSwitcher(.all)

    #expect(
      Self.targets(harness.model, in: .recent)
        == [.worktree(harness.main.id), .worktree(harness.feature.id)]
    )
  }

  @Test func aSearchKeptForTheFilesScopeAnswersAllsFewerWithoutSearchingAgain() throws {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.trackedFiles[harness.main.id] = Self.tracked(["src/main.swift", "src/app.swift"])
    harness.model.toggleQuickSwitcher(.files)
    harness.model.setQuickSwitcherText("swift")
    _ = harness.model.quickSwitcherResults
    let kept = try #require(harness.model.fileTreeCache[harness.main.id]?.quickSwitcherSearch)
    harness.model.fileTreeCache[harness.main.id]?.quickSwitcherSearch = QuickSwitcherFileSearch(
      query: kept.query,
      items: [harness.model.quickSwitcherFile("src/app.swift", in: harness.main.id)],
    )

    harness.model.setQuickSwitcherScope(.all)

    #expect(
      Self.targets(harness.model, in: .files(worktreeName: "main"))
        == [.file(path: "src/app.swift", worktreeID: harness.main.id)]
    )
  }

  @Test func aSearchKeptForAllAnswersTheFilesScopeWithoutSearchingAgain() throws {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.trackedFiles[harness.main.id] = Self.tracked(["src/main.swift", "src/app.swift"])
    harness.model.toggleQuickSwitcher(.all)
    harness.model.setQuickSwitcherText("swift")
    _ = harness.model.quickSwitcherResults
    let kept = try #require(harness.model.fileTreeCache[harness.main.id]?.quickSwitcherSearch)
    harness.model.fileTreeCache[harness.main.id]?.quickSwitcherSearch = QuickSwitcherFileSearch(
      query: kept.query,
      items: [harness.model.quickSwitcherFile("src/app.swift", in: harness.main.id)],
    )

    harness.model.setQuickSwitcherScope(.files)

    #expect(
      Self.targets(harness.model, in: .files(worktreeName: "main"))
        == [.file(path: "src/app.swift", worktreeID: harness.main.id)]
    )
  }

  @Test func worktreesListInTheSidebarsOrderNotTheOrderGitGaveThem() {
    let harness = Harness()
    let project = harness.project.id
    let zeta = Worktree(
      path: harness.root.appendingPathComponent("zeta"),
      projectID: project,
      head: "c",
      branch: "zeta",
    )
    let alpha = Worktree(
      path: harness.root.appendingPathComponent("alpha"),
      projectID: project,
      head: "d",
      branch: "alpha",
    )
    harness.store.replaceWorktrees([harness.main, zeta, alpha], forProject: project)

    harness.model.toggleQuickSwitcher(.worktrees)

    #expect(
      Self.targets(harness.model, in: .worktrees)
        == [.worktree(harness.main.id), .worktree(alpha.id), .worktree(zeta.id)]
    )
  }

  @Test func tabsListInTheirStripsOrder() throws {
    let harness = Harness()
    let first = harness.openBackgroundTab()
    let second = try #require(harness.model.workspace.activeTab(in: harness.main.id))

    harness.model.moveTab(second.id, .before, anchor: first.id)
    harness.model.toggleQuickSwitcher(.tabs)

    #expect(
      Self.targets(harness.model, in: .tabs)
        == [.pane(second.focusedSessionID), .pane(first.focusedSessionID)]
    )
  }

  @Test func aFailedAgentWantsTheUserAsTheBoardsWaitingColumnSays() throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let pane = try #require(harness.model.workspace.sessions(in: harness.main.id).first)
    harness.messageSource.send(
      SessionStateReport(state: .failed, sessionID: pane.id, agentID: "claude")
    )

    harness.model.toggleQuickSwitcher(.all)

    #expect(Self.targets(harness.model, in: .waiting) == [.pane(pane.id)])
  }

  @Test func aWorktreeRowReadsItsProjectThenBranchWithItsCustomNameAfter() {
    let harness = Harness()
    harness.store.setCustomName("Spike", forWorktree: harness.feature.id)

    harness.model.toggleQuickSwitcher(.worktrees)

    let rows = harness.model.quickSwitcherResults.sections.flatMap(\.items)
    let project = harness.project.name
    #expect(
      rows.map(\.title) == [
        "\(project) › \(harness.main.name)",
        "\(project) › \(harness.feature.name) (Spike)",
      ]
    )
    #expect(rows.map(\.location) == ["", ""])
  }

  @Test func anAgentRowReadsItsProjectBranchAndAgentWithItsPaneTitleAfter() throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = try #require(harness.model.workspace.activeTab(in: harness.main.id))
    let pane = try #require(harness.model.workspace.session(tab.focusedSessionID))
    harness.messageSource.send(
      SessionStateReport(state: .running, sessionID: pane.id, agentID: "claude")
    )

    harness.model.toggleQuickSwitcher(.agents)

    let row = try #require(harness.model.quickSwitcherResults.sections.first?.items.first)
    let agent = harness.model.agentDisplayName("claude")
    #expect(row.title == "\(harness.project.name) › \(harness.main.name) › \(agent)")
    #expect(row.location == harness.model.title(ofPane: pane, in: tab))
  }

  @Test func tabRowsReadTheirProjectBranchAndTabName() throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = try #require(harness.model.workspace.activeTab(in: harness.main.id))
    harness.store.openFileTab(path: "notes.md", in: harness.main.id)

    harness.model.toggleQuickSwitcher(.tabs)

    let rows = harness.model.quickSwitcherResults.sections.flatMap(\.items)
    let place = "\(harness.project.name) › \(harness.main.name)"
    #expect(
      rows.map(\.title) == ["\(place) › \(harness.model.title(of: tab))", "\(place) › notes.md"]
    )
    #expect(rows.map(\.location) == ["", ""])
  }

  @Test func eachPaneOfASplitTabSaysWhichPaneItIs() {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.splitActivePane(.horizontal)

    harness.model.toggleQuickSwitcher(.tabs)

    let tabs = harness.model.quickSwitcherResults.sections.first { $0.kind == .tabs }
    #expect(tabs?.items.map(\.position?.number) == [1, 2])
  }

  @Test func whatChangedListsAPathOnceThoughGitListsItAsRemovedAndNew() {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.trackedFiles[harness.main.id] = Self.tracked([])
    var status = WorktreeStatus()
    status.setChanges([
      StatusChange(path: "a.txt", kind: .deleted, lines: .notCounted),
      StatusChange(path: "a.txt", kind: .added, lines: .notCounted),
    ])
    harness.model.statuses[harness.main.id] = status

    harness.model.toggleQuickSwitcher(.files)

    #expect(
      Self.targets(harness.model, in: .changedFiles(worktreeName: "main"))
        == [.file(path: "a.txt", worktreeID: harness.main.id)]
    )
  }

  @Test func whatChangedListsAHundredAtMostAsASearchKeeps() {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.trackedFiles[harness.main.id] = Self.tracked([])
    var status = WorktreeStatus()
    status.setChanges(
      (0..<150).map { StatusChange(path: "out/\($0).txt", kind: .added, lines: .notCounted) }
    )
    harness.model.statuses[harness.main.id] = status

    harness.model.toggleQuickSwitcher(.files)

    #expect(Self.targets(harness.model, in: .changedFiles(worktreeName: "main")).count == 100)
  }

  @Test func emptyWithNothingWaitingOrRecentItListsEveryWorktree() {
    let harness = Harness()

    harness.model.toggleQuickSwitcher(.all)

    #expect(Self.kinds(harness.model) == [.worktrees])
    #expect(
      Self.targets(harness.model, in: .worktrees)
        == [.worktree(harness.main.id), .worktree(harness.feature.id)]
    )
  }

  @Test func aWaitingAgentRanksAboveAnEqualMatchThatIsNotWaiting() throws {
    let harness = Harness()
    let quiet = harness.openBackgroundTab()
    let waiting = try #require(harness.model.workspace.activeTab(in: harness.main.id))
    harness.messageSource.send(
      SessionStateReport(state: .running, sessionID: quiet.focusedSessionID, agentID: "claude")
    )
    harness.messageSource.send(
      SessionStateReport(state: .attention, sessionID: waiting.focusedSessionID, agentID: "claude")
    )
    harness.model.toggleQuickSwitcher(.all)

    harness.model.setQuickSwitcherText("claude")

    #expect(
      Array(Self.targets(harness.model, in: .places).prefix(2))
        == [.pane(waiting.focusedSessionID), .pane(quiet.focusedSessionID)]
    )
  }

  @Test func aWorktreeHoldingAWaitingAgentIsNotLiftedAsTheAgentIs() throws {
    let harness = Harness()
    harness.model.select(harness.feature)
    let pane = try #require(harness.model.workspace.sessions(in: harness.feature.id).first)
    harness.messageSource.send(
      SessionStateReport(state: .attention, sessionID: pane.id, agentID: "claude")
    )
    harness.model.toggleQuickSwitcher(.worktrees)

    harness.model.setQuickSwitcherText("a")

    #expect(
      Self.targets(harness.model, in: .worktrees)
        == [.worktree(harness.main.id), .worktree(harness.feature.id)]
    )
  }

  @Test func aProjectsOwnNameListsItAboveTheWorktreesAndTabsUnderIt() throws {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.toggleQuickSwitcher(.all)

    harness.model.setQuickSwitcherText(harness.project.name)

    #expect(Self.targets(harness.model, in: .places).first == .project(harness.project.id))
  }

  @Test func aRowsKindBreaksATieButNeverOutweighsABetterMatch() throws {
    let harness = Harness()
    let agentTab = harness.openBackgroundTab()
    harness.model.renameTab(agentTab.id, to: "feature flags")
    harness.messageSource.send(
      SessionStateReport(state: .running, sessionID: agentTab.focusedSessionID, agentID: "claude")
    )
    harness.model.toggleQuickSwitcher(.all)

    harness.model.setQuickSwitcherText("feature")

    let places = Self.targets(harness.model, in: .places)
    let worktree = try #require(places.firstIndex(of: .worktree(harness.feature.id)))
    let agent = try #require(places.firstIndex(of: .pane(agentTab.focusedSessionID)))
    #expect(worktree < agent)
  }

  @Test func eachStateListsItsAgentsNewestFirstAsTheBoardDoesBarWaitingLongestFirst() throws {
    let harness = Harness()
    let older = harness.openBackgroundTab()
    let newer = try #require(harness.model.workspace.activeTab(in: harness.main.id))
    for tab in [older, newer] {
      harness.messageSource.send(
        SessionStateReport(state: .running, sessionID: tab.focusedSessionID, agentID: "claude")
      )
    }

    harness.model.toggleQuickSwitcher(.agents)

    #expect(
      Self.targets(harness.model, in: .agents(.running))
        == [.pane(newer.focusedSessionID), .pane(older.focusedSessionID)]
    )
  }

  @Test func theAgentsScopeGroupsAgentsByStateMostPressingFirstAndLeavesShellsOut() throws {
    let harness = Harness()
    let working = harness.openBackgroundTab()
    let waiting = try #require(harness.model.workspace.activeTab(in: harness.main.id))
    harness.model.newTab()
    harness.messageSource.send(
      SessionStateReport(state: .running, sessionID: working.focusedSessionID, agentID: "claude")
    )
    harness.messageSource.send(
      SessionStateReport(state: .attention, sessionID: waiting.focusedSessionID, agentID: "codex")
    )

    harness.model.toggleQuickSwitcher(.agents)

    #expect(Self.kinds(harness.model) == [.agents(.attention), .agents(.running)])
    #expect(
      Self.targets(harness.model, in: .agents(.attention)) == [.pane(waiting.focusedSessionID)]
    )
  }

  @Test func typedTextFindsTheSelectedWorktreesFilesAfterThePlaces() {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.trackedFiles[harness.main.id] = Self.tracked(["README.md", "src/main.swift"])
    harness.model.toggleQuickSwitcher(.all)

    harness.model.setQuickSwitcherText("main")

    #expect(Self.kinds(harness.model) == [.places, .files(worktreeName: "main")])
    #expect(
      Self.targets(harness.model, in: .files(worktreeName: "main"))
        == [.file(path: "src/main.swift", worktreeID: harness.main.id)]
    )
  }

  @Test func aRenderWithTheSameTextAndListingReusesTheLastFileSearch() throws {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.trackedFiles[harness.main.id] = Self.tracked(["src/main.swift", "src/app.swift"])
    harness.model.toggleQuickSwitcher(.files)
    harness.model.setQuickSwitcherText("swift")
    _ = harness.model.quickSwitcherResults
    let kept = try #require(harness.model.fileTreeCache[harness.main.id]?.quickSwitcherSearch)
    harness.model.fileTreeCache[harness.main.id]?.quickSwitcherSearch = QuickSwitcherFileSearch(
      query: kept.query,
      items: [harness.model.quickSwitcherFile("src/app.swift", in: harness.main.id)],
    )
    let files = QuickSwitcherSection.Kind.files(worktreeName: "main")

    #expect(
      Self.targets(harness.model, in: files)
        == [.file(path: "src/app.swift", worktreeID: harness.main.id)]
    )

    harness.model.trackedFiles[harness.main.id] = Self.tracked(["src/main.swift"])
    #expect(
      Self.targets(harness.model, in: files)
        == [.file(path: "src/main.swift", worktreeID: harness.main.id)]
    )
  }

  @Test func closingDropsTheKeptFileSearch() {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.trackedFiles[harness.main.id] = Self.tracked(["src/main.swift"])
    harness.model.toggleQuickSwitcher(.files)
    harness.model.setQuickSwitcherText("main")
    _ = harness.model.quickSwitcherResults

    harness.model.closeQuickSwitcher()

    #expect(harness.model.fileTreeCache[harness.main.id]?.quickSwitcherSearch == nil)
  }

  @Test func theFilesScopeEmptyListsWhatChangedInTheSelectedWorktree() {
    let harness = Harness()
    harness.model.select(harness.main)
    var status = WorktreeStatus()
    status.setChanges([
      StatusChange(path: "b.txt", kind: .modified, lines: .counted(insertions: 1, deletions: 0)),
      StatusChange(path: "a.txt", kind: .added, lines: .counted(insertions: 2, deletions: 0)),
    ])
    harness.model.statuses[harness.main.id] = status
    harness.model.trackedFiles[harness.main.id] = Self.tracked(["a.txt", "b.txt"])

    harness.model.toggleQuickSwitcher(.files)

    #expect(
      Self.targets(harness.model, in: .changedFiles(worktreeName: "main")) == [
        .file(path: "a.txt", worktreeID: harness.main.id),
        .file(path: "b.txt", worktreeID: harness.main.id),
      ]
    )
  }

  @Test func whatChangedLeavesOutASubmoduleAndANestedRepositoryNeitherOfWhichOpens() {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.trackedFiles[harness.main.id] = TrackedFiles(
      paths: ["vendor/lib", "a.txt"],
      submodulePaths: ["vendor/lib"],
      notCheckedOutPaths: [],
      isCapped: false,
    )
    var status = WorktreeStatus()
    status.setChanges(
      ["vendor/lib", "tools/", "a.txt"].map { path in
        StatusChange(path: path, kind: .modified, lines: .notCounted)
      }
    )
    harness.model.statuses[harness.main.id] = status

    harness.model.toggleQuickSwitcher(.files)

    #expect(
      Self.targets(harness.model, in: .changedFiles(worktreeName: "main"))
        == [.file(path: "a.txt", worktreeID: harness.main.id)]
    )
  }

  @Test func filesStillBeingReadAreSaidToBeReadNotMissing() {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.toggleQuickSwitcher(.files)
    harness.model.setQuickSwitcherText("readme")

    harness.model.pendingTrackedFilesReads[harness.main.id] = Task {}

    #expect(harness.model.quickSwitcherResults.emptyReason == .readingFiles)
  }

  @Test func aLargeListingStillBeingBuiltIsSaidToBeReadNotMissing() throws {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.trackedFiles[harness.main.id] = Self.tracked(["src/main.swift"])
    harness.model.toggleQuickSwitcher(.files)
    harness.model.setQuickSwitcherText("readme")
    _ = harness.model.quickSwitcherResults
    let built = try #require(harness.model.fileTreeCache[harness.main.id])

    harness.model.fileTreeCache[harness.main.id] = FileTreeCacheEntry(
      sources: built.sources,
      tree: built.tree,
      awaitsListing: true,
      awaitsChanges: false,
    )
    harness.model.pendingFileTreeListings[harness.main.id] = Task {}

    #expect(harness.model.quickSwitcherResults.emptyReason == .readingFiles)
  }

  @Test func whatChangedWaitsForTheListingThatTellsASubmoduleFromAFile() {
    let harness = Harness()
    harness.model.select(harness.main)
    var status = WorktreeStatus()
    status.setChanges([StatusChange(path: "vendor/lib", kind: .modified, lines: .notCounted)])
    harness.model.statuses[harness.main.id] = status
    harness.model.toggleQuickSwitcher(.files)

    harness.model.pendingTrackedFilesReads[harness.main.id] = Task {}

    #expect(harness.model.quickSwitcherResults.sections == [])
    #expect(harness.model.quickSwitcherResults.emptyReason == .readingFiles)
  }

  @Test func anEmptyFilesScopeIsNotHeldUpByAListingBuiltForTextSinceDeleted() throws {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.trackedFiles[harness.main.id] = Self.tracked(["src/main.swift"])
    harness.model.toggleQuickSwitcher(.files)
    harness.model.setQuickSwitcherText("readme")
    _ = harness.model.quickSwitcherResults
    let built = try #require(harness.model.fileTreeCache[harness.main.id])
    harness.model.fileTreeCache[harness.main.id] = FileTreeCacheEntry(
      sources: built.sources,
      tree: built.tree,
      awaitsListing: true,
      awaitsChanges: false,
    )
    harness.model.pendingFileTreeListings[harness.main.id] = Task {}

    harness.model.setQuickSwitcherText("")

    #expect(harness.model.quickSwitcherResults.emptyReason == .nothingToList)
  }

  @Test func aReadOfTheFilesEndingRedrawsAnEmptyFilesScopeWaitingOnIt() {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.toggleQuickSwitcher(.files)
    let redrawn = AtomicFlag()

    withObservationTracking {
      _ = harness.model.quickSwitcherResults
    } onChange: {
      redrawn.raise()
    }
    harness.model.fileTreeBuildLandings += 1

    #expect(redrawn.raised)
  }

  @Test func whatChangedIsListedThoughTheReadOfTheTrackedFilesFailed() {
    let harness = Harness()
    harness.model.select(harness.main)
    var status = WorktreeStatus()
    status.setChanges([StatusChange(path: "a.txt", kind: .modified, lines: .notCounted)])
    harness.model.statuses[harness.main.id] = status

    harness.model.toggleQuickSwitcher(.files)

    #expect(
      Self.targets(harness.model, in: .changedFiles(worktreeName: "main"))
        == [.file(path: "a.txt", worktreeID: harness.main.id)]
    )
  }

  @Test func aKeptFileSearchIsLetGoOnceItsWorktreesTreeTakesAnotherListing() {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.trackedFiles[harness.main.id] = Self.tracked(["src/main.swift"])
    harness.model.toggleQuickSwitcher(.all)
    harness.model.setQuickSwitcherText("main")
    _ = harness.model.quickSwitcherResults
    harness.model.setQuickSwitcherScope(.commands)
    harness.model.trackedFiles[harness.main.id] = Self.tracked(["src/main.swift", "a.txt"])

    _ = harness.model.fileTree(of: harness.main.id)

    #expect(harness.model.fileTreeCache[harness.main.id]?.quickSwitcherSearch == nil)
  }

  @Test func tabbingFromAllRoundToFilesReusesTheSearchKept() throws {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.trackedFiles[harness.main.id] = Self.tracked(["src/main.swift", "src/app.swift"])
    harness.model.toggleQuickSwitcher(.all)
    harness.model.setQuickSwitcherText("swift")
    _ = harness.model.quickSwitcherResults
    let kept = try #require(harness.model.fileTreeCache[harness.main.id]?.quickSwitcherSearch)
    harness.model.fileTreeCache[harness.main.id]?.quickSwitcherSearch = QuickSwitcherFileSearch(
      query: kept.query,
      items: [harness.model.quickSwitcherFile("src/app.swift", in: harness.main.id)],
    )

    for _ in 0..<4 {
      harness.model.stepQuickSwitcherScope(.next)
      _ = harness.model.quickSwitcherResults
    }

    #expect(harness.model.quickSwitcher?.scope == .files)
    #expect(
      Self.targets(harness.model, in: .files(worktreeName: "main"))
        == [.file(path: "src/app.swift", worktreeID: harness.main.id)]
    )
  }

  @Test func whatChangedIsListedWithoutBuildingTheWholeListing() {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.trackedFiles[harness.main.id] = Self.tracked(["a.txt"])
    var status = WorktreeStatus()
    status.setChanges([StatusChange(path: "a.txt", kind: .modified, lines: .notCounted)])
    harness.model.statuses[harness.main.id] = status
    harness.model.toggleQuickSwitcher(.files)

    _ = harness.model.quickSwitcherResults

    #expect(harness.model.fileTreeCache[harness.main.id] == nil)
  }

  @Test func whatChangedLeavesOutAFileThatCannotBeOpened() {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.trackedFiles[harness.main.id] = Self.tracked(["a.txt"])
    var status = WorktreeStatus()
    status.setChanges(
      ["a.txt", "caf\u{FFFD}.txt"].map { path in
        StatusChange(path: path, kind: .modified, lines: .notCounted)
      }
    )
    harness.model.statuses[harness.main.id] = status

    harness.model.toggleQuickSwitcher(.files)

    #expect(
      Self.targets(harness.model, in: .changedFiles(worktreeName: "main"))
        == [.file(path: "a.txt", worktreeID: harness.main.id)]
    )
  }

  @Test func filesReadOnceAndBeingReadAgainMatchNothingRatherThanAwaitAnything() {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.trackedFiles[harness.main.id] = Self.tracked(["src/main.swift"])
    harness.model.toggleQuickSwitcher(.files)
    harness.model.setQuickSwitcherText("readme")

    harness.model.pendingTrackedFilesReads[harness.main.id] = Task {}

    #expect(harness.model.quickSwitcherResults.emptyReason == .noMatch)
  }

  @Test func anEmptyListSaysWhetherTheTextMatchedNothingOrThereIsNothingYet() {
    let harness = Harness()
    harness.model.toggleQuickSwitcher(.agents)
    #expect(harness.model.quickSwitcherResults.emptyReason == .nothingToList)

    harness.model.setQuickSwitcherText("zzz")
    #expect(harness.model.quickSwitcherResults.emptyReason == .noMatch)
  }

  @Test func commandsAreTheMenusEnabledItemsWithTheirKeys() throws {
    let harness = Harness()
    harness.platform.menuItems = [
      PlatformMenuItem(
        path: ["Terminal", "Split Right"],
        isEnabled: true,
        isChecked: false,
        shortcut: "⌘D",
      ),
      PlatformMenuItem(path: ["Edit", "Paste"], isEnabled: false, isChecked: false),
    ]

    harness.model.toggleQuickSwitcher(.commands)

    let items = try #require(harness.model.quickSwitcherResults.sections.first?.items)
    #expect(items.map(\.target) == [.command(path: ["Terminal", "Split Right"])])
    #expect(items.first?.title == "Split Right")
    #expect(items.first?.location == "Terminal")
    #expect(items.first?.shortcut == "⌘D")
  }

  @Test func aWorktreeGoneFromGitLeavesRecent() {
    let harness = Harness()
    harness.model.select(harness.feature)
    harness.model.select(harness.main)

    harness.model.forgetWorktrees([harness.feature.id])

    #expect(harness.model.recentWorktreeIDs == [harness.main.id])
  }
}
