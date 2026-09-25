import Foundation
import Testing

@testable import MultishellCore

@Suite @MainActor
struct WorkspaceLookupTests {
  @Test func aWorktreesPanesAreCountedAcrossItsTabsAndSplits() {
    let (store, _, worktree) = demoStore()
    let split = store.openTab(in: worktree.id)!
    store.splitFocusedPane(of: split.id, axis: .vertical)
    store.openTab(in: worktree.id)

    #expect(store.workspace.paneCount(in: worktree.id) == 3)
  }

  @Test func anotherWorktreesPanesAreNotCounted() {
    let (store, project, main) = demoStore()
    let feature = Worktree(
      path: main.path.appendingPathComponent("feature"), projectID: project.id, head: "b",
      branch: "feature")
    store.replaceWorktrees([main, feature], forProject: project.id)
    store.openTab(in: feature.id)

    #expect(store.workspace.paneCount(in: main.id) == 0)
  }

  @Test func theCheckedOutBranchesAreEveryWorktreesButADetachedOnes() {
    let (store, project, main) = demoStore()
    let feature = Worktree(
      path: main.path.appendingPathComponent("feature"), projectID: project.id, head: "b",
      branch: "feature")
    let detached = Worktree(
      path: main.path.appendingPathComponent("detached"), projectID: project.id, head: "c",
      branch: nil)
    store.replaceWorktrees([main, feature, detached], forProject: project.id)

    #expect(store.workspace.checkedOutBranches(of: project.id) == ["main", "feature"])
  }

  @Test func anotherProjectsBranchesAreNotCheckedOutHere() {
    let (store, _, _) = demoStore()
    let other = store.addProject(at: URL(fileURLWithPath: "/repos/other"))

    #expect(store.workspace.checkedOutBranches(of: other.id).isEmpty)
  }
}
