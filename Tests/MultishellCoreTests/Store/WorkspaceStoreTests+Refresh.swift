import Foundation
import Testing

@testable import MultishellCore

extension WorkspaceStoreTests {
  static func twoProjectsListingOneWorktree()
    -> (store: WorkspaceStore, original: Project, shared: Worktree, copy: Project)
  {
    let (store, original, main) = demoStore()
    let copy = store.addProject(at: URL(fileURLWithPath: "/repos/copy"))
    let path = URL(fileURLWithPath: "/repos/linked")
    let shared = Worktree(path: path, projectID: original.id, head: "abc1234", branch: "feature")
    store.replaceWorktrees([main, shared], forProject: original.id)
    var copysRow = shared
    copysRow.projectID = copy.id
    store.replaceWorktrees([copysRow], forProject: copy.id)
    return (store, original, shared, copy)
  }

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
    #expect(counter.changes == 2, "a second change is counted, not merged into the first")
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

  @Test func removingAProjectLeavesAWorktreeAnotherProjectListsWithItsTabAndName() {
    let (store, original, shared, copy) = Self.twoProjectsListingOneWorktree()
    let tab = store.openTab(in: shared.id)!
    store.setCustomName("Shared", forWorktree: shared.id)
    store.setHidden(true, forWorktree: shared.id)

    let discarded = store.removeProject(copy.id)

    #expect(!discarded.contains(shared.id))
    #expect(store.workspace.worktrees(of: original.id).map(\.id).contains(shared.id))
    #expect(store.workspace.tabs.map(\.id) == [tab.id])
    #expect(store.workspace.customWorktreeNames[shared.id] == "Shared")
    #expect(store.workspace.hiddenWorktreeIDs.contains(shared.id))
  }

  @Test func aRefreshDroppingAWorktreeAnotherProjectListsLeavesItsRowAndTab() {
    let (store, original, shared, copy) = Self.twoProjectsListingOneWorktree()
    let tab = store.openTab(in: shared.id)!

    let discarded = store.replaceWorktrees([], forProject: copy.id)

    #expect(!discarded.contains(shared.id))
    #expect(store.workspace.worktrees(of: original.id).map(\.id).contains(shared.id))
    #expect(store.workspace.tabs.map(\.id) == [tab.id])
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
}
