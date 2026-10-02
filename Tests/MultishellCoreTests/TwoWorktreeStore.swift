import Foundation

@testable import MultishellCore

/// `demoStore()` with a second worktree of the same project, `/repos/demo-b`, listed beside it.
@MainActor
func twoWorktreeStore() -> (store: WorkspaceStore, main: Worktree, other: Worktree) {
  let (store, project, main) = demoStore()
  let other = Worktree(
    path: URL(fileURLWithPath: "/repos/demo-b"), projectID: project.id, head: "b", branch: "b")
  store.replaceWorktrees([main, other], forProject: project.id)
  return (store, main, other)
}
