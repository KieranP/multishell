import Foundation
import Testing

@testable import MultishellCore

extension WorkspaceStoreTests {
  private func storeWithThreeProjects() -> (store: WorkspaceStore, worktree: Worktree) {
    let store = WorkspaceStore()
    let project = store.addProject(at: URL(fileURLWithPath: "/repos/a"))
    store.addProject(at: URL(fileURLWithPath: "/repos/b"))
    store.addProject(at: URL(fileURLWithPath: "/repos/c"))
    let worktree = Worktree(
      path: project.path,
      projectID: project.id,
      head: "x",
      branch: "main",
      isPrimary: true,
    )
    store.replaceWorktrees([worktree], forProject: project.id)
    return (store, worktree)
  }

  @Test func aProjectMovesToAPlaceCountedInTheListAsItStands() {
    let (store, _) = storeWithThreeProjects()
    store.moveProject(at: 0, to: 3)
    #expect(store.workspace.projects.map(\.name) == ["b", "c", "a"])
    store.moveProject(at: 2, to: 0)
    #expect(store.workspace.projects.map(\.name) == ["a", "b", "c"])
  }

  @Test func aMoveOutsideTheListIsIgnoredNotACrash() {
    let (store, _) = storeWithThreeProjects()
    store.moveProject(at: 0, to: 4)
    store.moveProject(at: 7, to: 0)
    store.moveProject(at: 1, to: -1)
    #expect(store.workspace.projects.map(\.name) == ["a", "b", "c"])
  }

  @Test func aTabMovesBesideAnotherAndAnUnknownAnchorMovesNothing() {
    let (store, worktree) = storeWithThreeProjects()
    let firstTab = store.openTab(in: worktree.id)!
    let secondTab = store.openTab(in: worktree.id)!
    let thirdTab = store.openTab(in: worktree.id)!

    store.moveTab(thirdTab.id, .before, anchor: firstTab.id)
    #expect(
      store.workspace.tabs(in: worktree.id).map(\.id) == [thirdTab.id, firstTab.id, secondTab.id]
    )

    store.moveTab(firstTab.id, .before, anchor: UUID())
    #expect(
      store.workspace.tabs(in: worktree.id).map(\.id) == [thirdTab.id, firstTab.id, secondTab.id]
    )

    // The trailing half of the last tab, which is the only way to the end
    // of the strip: there is no tab past it to land before.
    store.moveTab(thirdTab.id, .after, anchor: secondTab.id)
    #expect(
      store.workspace.tabs(in: worktree.id).map(\.id) == [firstTab.id, secondTab.id, thirdTab.id]
    )
  }
}
