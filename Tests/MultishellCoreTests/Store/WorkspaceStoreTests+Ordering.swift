import Foundation
import Testing

@testable import MultishellCore

extension WorkspaceStoreTests {
  private func store() -> (WorkspaceStore, Worktree) {
    let store = WorkspaceStore()
    let project = store.addProject(at: URL(fileURLWithPath: "/repos/a"))
    store.addProject(at: URL(fileURLWithPath: "/repos/b"))
    store.addProject(at: URL(fileURLWithPath: "/repos/c"))
    let worktree = Worktree(
      path: project.path, projectID: project.id, head: "x", branch: "main", isPrimary: true)
    store.replaceWorktrees([worktree], forProject: project.id)
    return (store, worktree)
  }

  @Test func aProjectMovesToAPlaceCountedInTheListAsItStands() {
    let (store, _) = store()
    store.moveProject(at: 0, to: 3)
    #expect(store.workspace.projects.map(\.name) == ["b", "c", "a"])
    store.moveProject(at: 2, to: 0)
    #expect(store.workspace.projects.map(\.name) == ["a", "b", "c"])
  }

  @Test func aMoveOutsideTheListIsIgnoredNotACrash() {
    let (store, _) = store()
    store.moveProject(at: 0, to: 4)
    store.moveProject(at: 7, to: 0)
    store.moveProject(at: 1, to: -1)
    #expect(store.workspace.projects.map(\.name) == ["a", "b", "c"])
  }

  @Test func tabsMoveWithinTheirWorktreeOnly() {
    let (store, worktree) = store()
    let t1 = store.openTab(in: worktree.id)!
    let t2 = store.openTab(in: worktree.id)!
    let t3 = store.openTab(in: worktree.id)!

    store.moveTab(t3.id, .before, t1.id)
    #expect(store.workspace.tabs(in: worktree.id).map(\.id) == [t3.id, t1.id, t2.id])

    store.moveTab(t1.id, .before, UUID())
    #expect(store.workspace.tabs(in: worktree.id).map(\.id) == [t3.id, t1.id, t2.id])

    // The trailing half of the last tab, which is the only way to the end
    // of the strip: there is no tab past it to land before.
    store.moveTab(t3.id, .after, t2.id)
    #expect(store.workspace.tabs(in: worktree.id).map(\.id) == [t1.id, t2.id, t3.id])
  }

  @Test func nextAndPreviousWrapAround() {
    let (store, worktree) = store()
    let t1 = store.openTab(in: worktree.id)!
    let t2 = store.openTab(in: worktree.id)!

    #expect(store.workspace.tab(after: t2.id)?.id == t1.id)
    #expect(store.workspace.tab(before: t1.id)?.id == t2.id)
    store.closeTab(t2.id)
    #expect(store.workspace.tab(after: t1.id) == nil)
  }
}
