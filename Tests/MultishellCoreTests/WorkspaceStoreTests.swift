import Foundation
import Testing

@testable import MultishellCore

@MainActor
private func demoStore() -> (store: WorkspaceStore, project: Project, worktree: Worktree) {
  let store = WorkspaceStore()
  let project = store.addProject(at: URL(fileURLWithPath: "/repos/demo"))
  let worktree = Worktree(
    path: URL(fileURLWithPath: "/repos/demo"),
    projectID: project.id,
    head: "abc1234",
    branch: "main",
    isPrimary: true
  )
  store.replaceWorktrees([worktree], forProject: project.id)
  return (store, project, worktree)
}

/// Counts how often the workspace changes, the way autosave and the views
/// see it. The callback fires synchronously on the mutating actor.
@MainActor
private final class ChangeCounter {
  private(set) var changes = 0

  init(_ store: WorkspaceStore) {
    withObservationTracking {
      _ = store.workspace
    } onChange: {
      MainActor.assumeIsolated { self.changes += 1 }
    }
  }
}

@Suite @MainActor
struct WorkspaceStoreTests {
  @Test func addingTheSameProjectTwiceIsIdempotent() {
    let store = WorkspaceStore()
    store.addProject(at: URL(fileURLWithPath: "/repos/demo"))
    store.addProject(at: URL(fileURLWithPath: "/repos/demo/"))
    #expect(store.workspace.projects.count == 1)
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

  @Test func closingTheActiveTabActivatesAnother() {
    let (store, _, worktree) = demoStore()
    let first = store.openTab(in: worktree.id)!
    let second = store.openTab(in: worktree.id)!

    #expect(store.workspace.activeTabByWorktree[worktree.id] == second.id)
    store.closeTab(second.id)
    #expect(store.workspace.activeTabByWorktree[worktree.id] == first.id)
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

  @Test func focusingASessionActivatesItsTab() {
    let (store, _, worktree) = demoStore()
    let first = store.openTab(in: worktree.id)!
    store.openTab(in: worktree.id)

    store.focusSession(first.focusedSessionID)

    #expect(store.workspace.activeTabByWorktree[worktree.id] == first.id)
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

    store.moveTab(a.id, before: b.id)

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

    #expect(store.workspace.activeTabByWorktree[other.id] == b.id)
    #expect(
      store.workspace.selectedWorktreeID == main.id,
      "focus is per worktree; selection is the user's")
  }
}
