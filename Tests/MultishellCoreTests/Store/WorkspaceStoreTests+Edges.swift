import Foundation
import TestScratch
import Testing

@testable import MultishellCore

extension WorkspaceStoreTests {
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
    let read = SharedSettingsSnapshot(
      asWritten: SharedProjectSettings(branchPrefix: "team/"),
      confined: SharedProjectSettings(branchPrefix: "team/"), modificationDate: Date(),
      hasBeenRead: true)
    store.updateSharedSettings(read, forProject: project.id)

    let touched = Flag()
    withObservationTracking {
      _ = store.workspace.projects
    } onChange: {
      touched.raise()
    }
    store.updateSharedSettings(read, forProject: project.id)

    #expect(!touched.raised)
    store.updateSharedSettings(SharedSettingsSnapshot.unread, forProject: project.id)
    #expect(touched.raised, "a read that says something else still does")
  }
}
