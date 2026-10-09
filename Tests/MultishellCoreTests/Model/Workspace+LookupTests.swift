import Foundation
import Testing

@testable import MultishellCore

@Suite @MainActor
struct WorkspaceLookupTests {
  @Test func theCheckedOutBranchesAreEveryWorktreesButADetachedOnes() {
    let (store, project, main) = demoStore()
    let feature = Worktree(
      path: main.path.appendingPathComponent("feature"),
      projectID: project.id,
      head: "b",
      branch: "feature",
    )
    let detached = Worktree(
      path: main.path.appendingPathComponent("detached"),
      projectID: project.id,
      head: "c",
      branch: nil,
    )
    store.replaceWorktrees([main, feature, detached], forProject: project.id)

    #expect(store.workspace.checkedOutBranches(of: project.id) == ["main", "feature"])
  }

  @Test func anotherProjectsBranchesAreNotCheckedOutHere() {
    let (store, _, _) = demoStore()
    let other = store.addProject(at: URL(fileURLWithPath: "/repos/other"))

    #expect(store.workspace.checkedOutBranches(of: other.id).isEmpty)
  }

  @Test func theNextAndPreviousTabWrapAndALoneTabHasNone() {
    let (store, _, worktree) = demoStore()
    let firstTab = store.openTab(in: worktree.id)!
    let secondTab = store.openTab(in: worktree.id)!

    #expect(store.workspace.tab(after: secondTab.id)?.id == firstTab.id)
    #expect(store.workspace.tab(before: firstTab.id)?.id == secondTab.id)
    store.closeTab(secondTab.id)
    #expect(store.workspace.tab(after: firstTab.id) == nil)
  }

  @Test func tabCyclingStaysInsideItsGroup() {
    let (store, _, worktree) = demoStore()
    let a = store.openTab(in: worktree.id)!
    let b = store.openTab(in: worktree.id)!
    let c = store.openTab(in: worktree.id)!
    let first = store.workspace.groups(in: worktree.id)[0]
    store.moveTab(c.id, .after, toNewGroupOf: first.id)

    #expect(store.workspace.tab(after: a.id)?.id == b.id)
    #expect(store.workspace.tab(after: b.id)?.id == a.id, "wraps within the group")
    #expect(store.workspace.tab(after: c.id) == nil, "a group of one has nowhere to go")
  }

  @Test func twoTabsShareAGroupOnlyWhileBothAreInIt() {
    let (store, _, worktree) = demoStore()
    let a = store.openTab(in: worktree.id)!
    let b = store.openTab(in: worktree.id)!
    let first = store.workspace.groups(in: worktree.id)[0]
    #expect(store.workspace.sharedGroup(of: a.id, and: b.id) == first.id)

    store.moveTab(b.id, .after, toNewGroupOf: first.id)
    #expect(store.workspace.sharedGroup(of: a.id, and: b.id) == nil)
    #expect(store.workspace.sharedGroup(of: a.id, and: UUID()) == nil, "and a tab that has gone")
  }

  /// A file hand-edited to name no focused group, read before repair has
  /// run: the first group answers, so the worktree still draws a strip.
  @Test func aWorktreeWithNoFocusedGroupFallsBackToItsFirst() {
    let (store, _, worktree) = demoStore()
    let tab = store.openTab(in: worktree.id)!
    var workspace = store.workspace
    let first = workspace.groups(in: worktree.id)[0]
    workspace.focusedGroupByWorktree = [:]

    #expect(workspace.focusedGroup(in: worktree.id)?.id == first.id)
    #expect(workspace.activeTab(in: worktree.id)?.id == tab.id)

    workspace.focusedGroupByWorktree[worktree.id] = UUID()
    #expect(workspace.focusedGroup(in: worktree.id)?.id == first.id, "and a group that has gone")
  }
}
