import Foundation
import Testing

@testable import MultishellCore

extension WorkspaceStoreTests {
  private func storeWithLinkedWorktree() -> (WorkspaceStore, Project, Worktree, Worktree) {
    let (store, project, main) = demoStore()
    let linked = Worktree(
      path: URL(fileURLWithPath: "/repos/trees/checkout"),
      projectID: project.id,
      head: "def5678",
      branch: "feat/checkout",
    )
    store.replaceWorktrees([main, linked], forProject: project.id)
    return (store, project, main, linked)
  }

  @Test func hidingAWorktreeMarksItAndUnhidingClearsIt() {
    let (store, _, _, linked) = storeWithLinkedWorktree()
    store.setHidden(true, worktree: linked.id)
    #expect(store.workspace.isHidden(linked))

    store.setHidden(false, worktree: linked.id)
    #expect(!store.workspace.isHidden(linked))
    #expect(store.workspace.hiddenWorktreeIDs.isEmpty)
  }

  @Test func theMainWorktreeCannotBeHidden() {
    let (store, _, main, _) = storeWithLinkedWorktree()
    store.setHidden(true, worktree: main.id)
    #expect(!store.workspace.isHidden(main))
  }

  @Test func hidingAWorktreeThatIsGoneIsIgnored() {
    let (store, _, _, _) = storeWithLinkedWorktree()
    store.setHidden(true, worktree: "/repos/vanished")
    #expect(store.workspace.hiddenWorktreeIDs.isEmpty)
  }

  @Test func aRemovedWorktreeLeavesNoHiddenMarkBehind() {
    let (store, project, main, linked) = storeWithLinkedWorktree()
    store.setHidden(true, worktree: linked.id)

    store.replaceWorktrees([main], forProject: project.id)
    #expect(store.workspace.hiddenWorktreeIDs.isEmpty)

    store.replaceWorktrees([main, linked], forProject: project.id)
    store.setHidden(true, worktree: linked.id)
    store.removeProject(project.id)
    #expect(store.workspace.hiddenWorktreeIDs.isEmpty, "a removed project takes its marks too")
  }
}
