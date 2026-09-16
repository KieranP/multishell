import Foundation

@testable import MultishellCore

/// One project at `/repos/demo` with its main worktree listed; nothing on disk.
@MainActor
func demoStore() -> (store: WorkspaceStore, project: Project, worktree: Worktree) {
  let store = WorkspaceStore()
  let project = store.addProject(at: URL(fileURLWithPath: "/repos/demo"))
  let worktree = Worktree(
    path: URL(fileURLWithPath: "/repos/demo"), projectID: project.id, head: "abc1234",
    branch: "main", isPrimary: true)
  store.replaceWorktrees([worktree], forProject: project.id)
  return (store, project, worktree)
}
