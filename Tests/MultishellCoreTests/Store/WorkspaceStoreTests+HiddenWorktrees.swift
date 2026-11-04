import Foundation
import Testing

@testable import MultishellCore

extension WorkspaceStoreTests {
  @Test func hidingAWorktreeMarksItAndUnhidingClearsIt() {
    let (store, _, linked) = twoWorktreeStore()
    store.setHidden(true, worktree: linked.id)
    #expect(store.workspace.isHidden(linked))

    store.setHidden(false, worktree: linked.id)
    #expect(!store.workspace.isHidden(linked))
    #expect(store.workspace.hiddenWorktreeIDs.isEmpty)
  }

  @Test func theMainWorktreeCannotBeHidden() {
    let (store, main, _) = twoWorktreeStore()
    store.setHidden(true, worktree: main.id)
    #expect(!store.workspace.isHidden(main))
  }

  @Test func hidingAWorktreeThatIsGoneIsIgnored() {
    let (store, _, _) = twoWorktreeStore()
    store.setHidden(true, worktree: "/repos/vanished")
    #expect(store.workspace.hiddenWorktreeIDs.isEmpty)
  }

  @Test func aRemovedWorktreeLeavesNoHiddenMarkBehind() {
    let (store, main, linked) = twoWorktreeStore()
    store.setHidden(true, worktree: linked.id)

    store.replaceWorktrees([main], forProject: main.projectID)
    #expect(store.workspace.hiddenWorktreeIDs.isEmpty)

    store.replaceWorktrees([main, linked], forProject: main.projectID)
    store.setHidden(true, worktree: linked.id)
    store.removeProject(main.projectID)
    #expect(store.workspace.hiddenWorktreeIDs.isEmpty, "a removed project takes its marks too")
  }
}
