import Foundation
import Testing

@testable import MultishellCore

extension WorkspaceStoreTests {
  @Test func aTabDroppedOnAnotherWorktreesTabStaysPut() {
    let (store, main, other) = twoWorktreeStore()
    let a = store.openTab(in: main.id)!
    let b = store.openTab(in: other.id)!

    store.moveTab(a.id, .before, anchor: b.id)

    #expect(store.workspace.tabs(in: main.id).map(\.id) == [a.id])
    #expect(store.workspace.tabs(in: other.id).map(\.id) == [b.id])
  }

  @Test func focusingASessionSwitchesTheActiveTabButNotTheSelectedWorktree() {
    let (store, main, other) = twoWorktreeStore()
    store.selectWorktree(main.id)
    let b = store.openTab(in: other.id)!

    store.focusSession(b.focusedSessionID)

    #expect(store.workspace.activeTab(in: other.id)?.id == b.id)
    #expect(
      store.workspace.selectedWorktreeID == main.id,
      "focus is per worktree; selection is the user's",
    )
  }

  @Test func aTabMovedToAnotherWorktreeTakesItsPanesAndLandsLast() {
    let (store, main, feature) = twoWorktreeStore()
    let settled = store.openTab(in: feature.id)!
    let moving = store.openTab(in: main.id)!
    store.splitFocusedPane(of: moving.id, axis: .vertical)

    #expect(store.moveTab(moving.id, toWorktree: feature.id))

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
    let (store, main, feature) = twoWorktreeStore()
    let tab = store.openTab(in: main.id)!

    store.moveTab(tab.id, toWorktree: feature.id)

    #expect(store.workspace.session(tab.focusedSessionID)?.workingDirectory == feature.path)
  }

  @Test func theWorktreeATabLeavesFallsBackToItsLastTab() {
    let (store, main, feature) = twoWorktreeStore()
    let first = store.openTab(in: main.id)!
    let second = store.openTab(in: main.id)!

    store.moveTab(second.id, toWorktree: feature.id)
    #expect(store.workspace.activeTab(in: main.id)?.id == first.id)

    store.moveTab(first.id, toWorktree: feature.id)
    #expect(store.workspace.activeTab(in: main.id)?.id == nil, "no tabs, no active one")
  }

  @Test func aTabIsNotMovedToAWorktreeThatCannotTakeIt() {
    let (store, _, worktree) = demoStore()
    let tab = store.openTab(in: worktree.id)!

    #expect(store.moveTab(tab.id, toWorktree: "/repos/nowhere") == false)
    #expect(store.moveTab(tab.id, toWorktree: worktree.id) == false, "already there")
    #expect(store.moveTab(UUID(), toWorktree: worktree.id) == false, "no such tab")
    #expect(store.workspace.tab(tab.id)?.worktreeID == worktree.id)
  }
}
