import Foundation
import Observation
import TestScratch
import Testing

@testable import MultishellCore

@Suite @MainActor
struct OrderedSaveTests {
  @Test func aSavePreparedEarlierNeverLandsOverOnePreparedLater() throws {
    let file = Scratch.path("ordered-save").appendingPathComponent("state.json")
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let store = WorkspaceStore(snapshot: WorkspaceSnapshot(fileURL: file))
    store.addProject(at: URL(fileURLWithPath: "/repos/a"))
    let first = try #require(store.prepareSave())
    store.addProject(at: URL(fileURLWithPath: "/repos/b"))
    let second = try #require(store.prepareSave())

    try second.run()
    try first.run()

    #expect(try WorkspaceSnapshot(fileURL: file).load().projects.count == 2)
  }
}

/// `replaceWorktrees` writes `workspace` twice, so firings between two reads of `changes`
/// count as one operation. A write of an equal value still fires.
@MainActor
private final class ChangeCounter {
  private var counted = 0
  private var firings = 0
  private let store: WorkspaceStore

  init(_ store: WorkspaceStore) {
    self.store = store
    arm()
  }

  var changes: Int {
    if firings > 0 {
      counted += 1
      firings = 0
    }
    return counted
  }

  /// One registration answers one write, so it is made again from each.
  private func arm() {
    withObservationTracking {
      _ = store.workspace
    } onChange: {
      MainActor.assumeIsolated {
        self.firings += 1
        self.arm()
      }
    }
  }
}

@Suite @MainActor
struct WorkspaceStoreTests {
  @Test func addingTheSameProjectTwiceIsIdempotent() {
    let store = WorkspaceStore()
    store.addProject(at: URL(fileURLWithPath: "/repos/demo"))
    store.addProject(at: URL(fileURLWithPath: "/repos/demo/"))
    store.addProject(at: URL(fileURLWithPath: "/repos/other/../demo"))
    store.addProject(at: URL(fileURLWithPath: "/repos/./demo/"))
    #expect(store.workspace.projects.count == 1)
    #expect(store.workspace.projects[0].id == "/repos/demo")
  }

  /// Identity reads the stored path, so every way in must normalise it.
  @Test func everySpellingOfADirectoryGivesTheSameIdentity() throws {
    let spellings = ["/repos/demo", "/repos/demo/", "/repos/x/../demo", "/repos/./demo//"]
    let projects = spellings.map { Project(path: URL(fileURLWithPath: $0)) }
    #expect(Set(projects.map(\.id)) == ["/repos/demo"])
    let worktrees = spellings.map {
      Worktree(path: URL(fileURLWithPath: $0), projectID: "/p", head: "h")
    }
    #expect(Set(worktrees.map(\.id)) == ["/repos/demo"])

    let decoded = try JSONDecoder().decode(
      Project.self, from: Data(#"{ "path": "file:///repos/x/../demo" }"#.utf8))
    #expect(decoded.id == "/repos/demo")
  }

  @Test func removingAProjectDropsItsWorktreesTabsAndSessions() {
    let (store, project, worktree) = demoStore()
    store.openTab(in: worktree.id)
    store.removeProject(project.id)

    #expect(store.workspace.projects.isEmpty)
    #expect(store.workspace.worktrees.isEmpty)
    #expect(store.workspace.tabs.isEmpty)
    #expect(store.workspace.sessions.isEmpty)
  }

  @Test func refreshDropsTabsForWorktreesThatVanished() {
    let (store, project, worktree) = demoStore()
    store.openTab(in: worktree.id)
    store.selectWorktree(worktree.id)

    store.replaceWorktrees([], forProject: project.id)

    #expect(store.workspace.tabs.isEmpty)
    #expect(store.workspace.sessions.isEmpty)
    #expect(store.workspace.selectedWorktreeID == nil)
  }

  @Test func aCustomNameIsTrimmedAndAnEmptyOneClearsIt() {
    let (store, _, worktree) = demoStore()
    store.setCustomName("  Checkout flow  ", forWorktree: worktree.id)
    #expect(store.workspace.customName(of: worktree.id) == "Checkout flow")
    #expect(store.workspace.displayName(of: worktree) == "Checkout flow")

    store.setCustomName("   ", forWorktree: worktree.id)
    #expect(store.workspace.worktreeNames.isEmpty, "a blank name is not a name")
    #expect(store.workspace.displayName(of: worktree) == "main", "the branch takes the row back")

    store.setCustomName("Later", forWorktree: worktree.id)
    store.setCustomName(nil, forWorktree: worktree.id)
    #expect(store.workspace.worktreeNames.isEmpty)
  }

  @Test func namingAWorktreeThatIsGoneIsIgnored() {
    let (store, _, _) = demoStore()
    store.setCustomName("Ghost", forWorktree: "/repos/vanished")
    #expect(store.workspace.worktreeNames.isEmpty)
  }

  /// The name is the user's, but it belongs to a directory that no longer
  /// exists; leaving it would put it back on whatever is made there next.
  @Test func aRemovedWorktreeLeavesNoNameBehind() {
    let (store, project, worktree) = demoStore()
    store.setCustomName("Checkout flow", forWorktree: worktree.id)

    store.replaceWorktrees([], forProject: project.id)
    #expect(store.workspace.worktreeNames.isEmpty)

    store.replaceWorktrees([worktree], forProject: project.id)
    store.setCustomName("Checkout flow", forWorktree: worktree.id)
    store.removeProject(project.id)
    #expect(store.workspace.worktreeNames.isEmpty, "a removed project takes its names too")
  }

  @Test func closingTheActiveTabActivatesAnother() {
    let (store, _, worktree) = demoStore()
    let first = store.openTab(in: worktree.id)!
    let second = store.openTab(in: worktree.id)!

    #expect(store.workspace.activeTab(in: worktree.id)?.id == second.id)
    store.closeTab(second.id)
    #expect(store.workspace.activeTab(in: worktree.id)?.id == first.id)
  }

  @Test func aTabMovedToAnotherWorktreeTakesItsPanesAndLandsLast() {
    let (store, project, main) = demoStore()
    let feature = Worktree(
      path: main.path.appendingPathComponent("feature"), projectID: project.id, head: "b",
      branch: "feature")
    store.replaceWorktrees([main, feature], forProject: project.id)
    let settled = store.openTab(in: feature.id)!
    let moving = store.openTab(in: main.id)!
    store.splitFocusedPane(of: moving.id, axis: .vertical)

    #expect(store.moveTab(moving.id, to: feature.id))

    #expect(store.workspace.tab(moving.id)?.worktreeID == feature.id)
    #expect(store.workspace.tabs(in: feature.id).map(\.id) == [settled.id, moving.id])
    #expect(store.workspace.tabs(in: main.id).isEmpty)
    #expect(store.workspace.sessions(in: feature.id).count == 3, "both panes came along")
    #expect(store.workspace.sessions(in: main.id).isEmpty)
    #expect(store.workspace.activeTab(in: feature.id)?.id == moving.id)
  }

  /// The panes' shell is resolved from the worktree, so a tab left on the old directory
  /// would open one project's shell in another project's checkout on the next launch.
  @Test func aMovedTabsPanesStartInTheWorktreeItLandedIn() {
    let (store, project, main) = demoStore()
    let feature = Worktree(
      path: main.path.appendingPathComponent("feature"), projectID: project.id, head: "b",
      branch: "feature")
    store.replaceWorktrees([main, feature], forProject: project.id)
    let tab = store.openTab(in: main.id)!

    store.moveTab(tab.id, to: feature.id)

    #expect(store.workspace.session(tab.focusedSessionID)?.workingDirectory == feature.path)
  }

  @Test func theWorktreeATabLeavesFallsBackToItsLastTab() {
    let (store, project, main) = demoStore()
    let feature = Worktree(
      path: main.path.appendingPathComponent("feature"), projectID: project.id, head: "b",
      branch: "feature")
    store.replaceWorktrees([main, feature], forProject: project.id)
    let first = store.openTab(in: main.id)!
    let second = store.openTab(in: main.id)!

    store.moveTab(second.id, to: feature.id)
    #expect(store.workspace.activeTab(in: main.id)?.id == first.id)

    store.moveTab(first.id, to: feature.id)
    #expect(store.workspace.activeTab(in: main.id)?.id == nil, "no tabs, no active one")
  }

  @Test func aTabIsNotMovedToAWorktreeThatCannotTakeIt() {
    let (store, _, worktree) = demoStore()
    let tab = store.openTab(in: worktree.id)!

    #expect(store.moveTab(tab.id, to: "/repos/nowhere") == false)
    #expect(store.moveTab(tab.id, to: worktree.id) == false, "already there")
    #expect(store.moveTab(UUID(), to: worktree.id) == false, "no such tab")
    #expect(store.workspace.tab(tab.id)?.worktreeID == worktree.id)
  }

  @Test func sessionsInheritTheWorktreeDirectory() {
    let (store, _, worktree) = demoStore()
    let tab = store.openTab(in: worktree.id)!
    let session = store.workspace.session(tab.focusedSessionID)
    #expect(session?.workingDirectory == worktree.path)
  }

  @Test func openingATabInAnUnknownWorktreeFails() {
    let store = WorkspaceStore()
    #expect(store.openTab(in: "/nowhere") == nil)
  }

  @Test func closingTheLastPaneClosesItsTab() {
    let (store, _, worktree) = demoStore()
    let tab = store.openTab(in: worktree.id)!

    store.closeSession(tab.focusedSessionID)

    #expect(store.workspace.tabs.isEmpty)
    #expect(store.workspace.sessions.isEmpty)
  }

  @Test func closingOneSideOfASplitKeepsTheTab() {
    let (store, _, worktree) = demoStore()
    let tab = store.openTab(in: worktree.id)!
    let original = tab.focusedSessionID
    let added = store.splitFocusedPane(of: tab.id, axis: .vertical)!

    store.closeSession(added.id)

    let survivor = store.workspace.tab(tab.id)
    #expect(survivor?.root == .terminal(original))
    #expect(survivor?.focusedSessionID == original)
    #expect(store.workspace.sessions.count == 1)
  }

  @Test func splittingAddsAPaneToTheSameTab() {
    let (store, _, worktree) = demoStore()
    let tab = store.openTab(in: worktree.id)!
    store.splitFocusedPane(of: tab.id, axis: .horizontal)

    #expect(store.workspace.tabs.count == 1)
    #expect(store.workspace.tab(tab.id)?.sessionIDs.count == 2)
    #expect(store.workspace.tab(tab.id)?.isSplit == true)
  }
}

@Suite @MainActor
struct TabTitleTests {
  @Test func aCustomTitleWinsOverTheStartingTitleUntilCleared() {
    let (store, _, worktree) = demoStore()
    let tab = store.openTab(in: worktree.id)!
    #expect(store.workspace.title(of: store.workspace.tab(tab.id)!) == "Shell")

    store.setCustomTitle("  build  ", forTab: tab.id)
    #expect(store.workspace.title(of: store.workspace.tab(tab.id)!) == "build")

    store.setCustomTitle("", forTab: tab.id)
    #expect(store.workspace.tab(tab.id)?.customTitle == nil)
    #expect(store.workspace.title(of: store.workspace.tab(tab.id)!) == "Shell")
  }

  @Test func aCommandTabStartsWithTheCommandsName() {
    let (store, _, worktree) = demoStore()
    let tab = store.openTab(in: worktree.id, command: ["/usr/bin/top", "-o", "cpu"])!
    #expect(store.workspace.title(of: tab) == "top")
  }
}

@Suite @MainActor
struct WorkspaceStoreEdgeTests {
  @Test func aRefreshThatLandsAfterItsProjectWasRemovedIsDropped() {
    let (store, project, worktree) = demoStore()
    store.removeProject(project.id)

    store.replaceWorktrees([worktree], forProject: project.id)

    #expect(store.workspace.worktrees.isEmpty, "would otherwise be polled for status forever")
  }

  @Test func anUnchangedRefreshDoesNotTouchTheWorkspace() {
    let (store, project, worktree) = demoStore()
    let counter = ChangeCounter(store)

    store.replaceWorktrees([worktree], forProject: project.id)
    #expect(counter.changes == 0, "a watcher tick with nothing new must not save or re-render")

    var moved = worktree
    moved.head = "moved"
    store.replaceWorktrees([moved], forProject: project.id)
    #expect(counter.changes == 1)
    moved.head = "moved again"
    store.replaceWorktrees([moved], forProject: project.id)
    #expect(counter.changes == 2, "a second change is counted, not folded into the first")
  }

  @Test func selectingAWorktreeThatIsGoneIsIgnored() {
    let (store, _, worktree) = demoStore()
    store.selectWorktree(worktree.id)
    store.selectWorktree("/repos/vanished")
    #expect(store.workspace.selectedWorktreeID == worktree.id)
    store.selectWorktree(nil)
    #expect(store.workspace.selectedWorktreeID == nil)
  }

  @Test func refreshKeepsTabsOfWorktreesThatSurvive() {
    let (store, project, worktree) = demoStore()
    let tab = store.openTab(in: worktree.id)!
    var moved = worktree
    moved.head = "def5678"

    store.replaceWorktrees([moved], forProject: project.id)

    #expect(store.workspace.tabs.map(\.id) == [tab.id])
    #expect(store.workspace.worktree(worktree.id)?.head == "def5678")
  }

  @Test func splitWeightsAreWrittenAtAPath() {
    let (store, _, worktree) = demoStore()
    let tab = store.openTab(in: worktree.id)!
    store.splitFocusedPane(of: tab.id, axis: .horizontal)

    store.setSplitWeights([3, 1], at: [], ofTab: tab.id)

    guard case .split(_, _, let weights)? = store.workspace.tab(tab.id)?.root else {
      Issue.record("expected a split")
      return
    }
    #expect(weights == [3, 1])
  }

  /// The same refusal `setGroupWeights` makes: a zero or a NaN is a pane
  /// nothing can be laid out in, and the one writer never sends one.
  @Test func splitWeightsThatCannotLayOutAPaneAreRefused() {
    let (store, _, worktree) = demoStore()
    let tab = store.openTab(in: worktree.id)!
    store.splitFocusedPane(of: tab.id, axis: .horizontal)
    store.setSplitWeights([3, 1], at: [], ofTab: tab.id)

    for refused in [[0, 1], [1, .nan], [1, .infinity], [-1, 2]] as [[Double]] {
      store.setSplitWeights(refused, at: [], ofTab: tab.id)
      guard case .split(_, _, let weights)? = store.workspace.tab(tab.id)?.root else {
        Issue.record("expected a split")
        return
      }
      #expect(weights == [3, 1], "\(refused)")
    }
  }

  @Test func focusingASessionActivatesItsTab() {
    let (store, _, worktree) = demoStore()
    let first = store.openTab(in: worktree.id)!
    store.openTab(in: worktree.id)

    store.focusSession(first.focusedSessionID)

    #expect(store.workspace.activeTab(in: worktree.id)?.id == first.id)
  }

  /// The engine reports focus on every click and showing, Ghostty's from inside a SwiftUI
  /// update, and every write re-runs the views and re-arms autosave.
  @Test func focusingTheSessionAlreadyFocusedWritesNothing() {
    let (store, _, worktree) = demoStore()
    let first = store.openTab(in: worktree.id)!
    store.openTab(in: worktree.id)
    store.focusSession(first.focusedSessionID)

    let counter = ChangeCounter(store)
    store.focusSession(first.focusedSessionID)
    store.activateTab(first.id)
    #expect(counter.changes == 0)
  }

  @Test func unknownIDsAreIgnored() {
    let (store, _, worktree) = demoStore()
    store.openTab(in: worktree.id)
    let before = store.workspace

    store.closeSession(UUID())
    store.closeTab(UUID())
    store.activateTab(UUID())
    store.setCustomTitle("x", forTab: UUID())
    store.setSplitWeights([1], at: [0], ofTab: UUID())

    #expect(store.workspace == before)
  }

  @Test func aMissingThemeFallsBackToDark() {
    var appearance = Appearance()
    appearance.themeID = "gone"
    #expect(appearance.theme() == .multishellDark)
  }

  @Test func updateSettingsOnlyTouchesThatProject() {
    let store = WorkspaceStore()
    let a = store.addProject(at: URL(fileURLWithPath: "/repos/a"))
    let b = store.addProject(at: URL(fileURLWithPath: "/repos/b"))

    store.updateSettings(ProjectSettings(branchPrefix: "k/"), forProject: a.id)

    #expect(store.workspace.project(a.id)?.settings.branchPrefix == "k/")
    #expect(store.workspace.project(b.id)?.settings.branchPrefix == nil)
  }

  /// Every activation re-reads each project's file, and a mutation is a
  /// whole-workspace save. Reading the same bytes is not a change.
  @Test func rereadingTheSameSharedSettingsTouchesNothing() {
    let store = WorkspaceStore()
    let project = store.addProject(at: URL(fileURLWithPath: "/repos/a"))
    let read = SharedSettingsRead(
      asWritten: SharedProjectSettings(branchPrefix: "team/"),
      confined: SharedProjectSettings(branchPrefix: "team/"), stamp: Date(), hasBeenRead: true)
    store.updateSharedSettings(read, forProject: project.id)

    let touched = Flag()
    withObservationTracking {
      _ = store.workspace.projects
    } onChange: {
      touched.raise()
    }
    store.updateSharedSettings(read, forProject: project.id)

    #expect(!touched.raised)
    store.updateSharedSettings(SharedSettingsRead.unread, forProject: project.id)
    #expect(touched.raised, "a read that says something else still does")
  }
}

@Suite @MainActor
struct CrossWorktreeTests {
  @Test func tabsCannotMoveBetweenWorktrees() {
    let (store, project, main) = demoStore()
    let other = Worktree(
      path: URL(fileURLWithPath: "/repos/demo-b"), projectID: project.id, head: "b", branch: "b")
    store.replaceWorktrees([main, other], forProject: project.id)
    let a = store.openTab(in: main.id)!
    let b = store.openTab(in: other.id)!

    store.moveTab(a.id, .before, b.id)

    #expect(store.workspace.tabs(in: main.id).map(\.id) == [a.id])
    #expect(store.workspace.tabs(in: other.id).map(\.id) == [b.id])
  }

  @Test func focusingASessionSwitchesTheActiveTabButNotTheSelectedWorktree() {
    let (store, project, main) = demoStore()
    let other = Worktree(
      path: URL(fileURLWithPath: "/repos/demo-b"), projectID: project.id, head: "b", branch: "b")
    store.replaceWorktrees([main, other], forProject: project.id)
    store.selectWorktree(main.id)
    let b = store.openTab(in: other.id)!

    store.focusSession(b.focusedSessionID)

    #expect(store.workspace.activeTab(in: other.id)?.id == b.id)
    #expect(
      store.workspace.selectedWorktreeID == main.id,
      "focus is per worktree; selection is the user's")
  }
}

/// The creation date is read off the filesystem on every listing, so a stat
/// that could not answer must not be taken as news.
@Suite
@MainActor
struct WorktreeCreationDateTests {
  private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

  private func worktree(dated: Date?) -> Worktree {
    Worktree(
      path: URL(fileURLWithPath: "/repos/demo"), projectID: "/repos/demo", head: "abc1234",
      branch: "main", isPrimary: true, createdAt: dated)
  }

  @Test func aDateOnceReadSurvivesAListingThatLostIt() {
    let (store, project, _) = demoStore()
    store.replaceWorktrees([worktree(dated: epoch)], forProject: project.id)
    #expect(store.workspace.worktrees.first?.createdAt == epoch)

    store.replaceWorktrees([worktree(dated: nil)], forProject: project.id)
    #expect(store.workspace.worktrees.first?.createdAt == epoch, "the stat failed, the date stands")
  }

  /// The point of keeping it: an undated listing is not a change, so it
  /// costs no save and no re-render.
  @Test func anUndatedListingIsNotAChange() {
    let (store, project, _) = demoStore()
    store.replaceWorktrees([worktree(dated: epoch)], forProject: project.id)
    let counter = ChangeCounter(store)

    store.replaceWorktrees([worktree(dated: nil)], forProject: project.id)
    #expect(counter.changes == 0)
  }

  /// A worktree genuinely recreated at the same path takes the new date:
  /// only a missing one falls back to what was known.
  @Test func aFreshDateAlwaysWins() {
    let (store, project, _) = demoStore()
    store.replaceWorktrees([worktree(dated: epoch)], forProject: project.id)
    let later = epoch.addingTimeInterval(86_400)

    store.replaceWorktrees([worktree(dated: later)], forProject: project.id)
    #expect(store.workspace.worktrees.first?.createdAt == later)
  }
}
