import Foundation
import TestScratch
import Testing

@testable import MultishellCore

extension WorkspaceStoreTests {
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
