import MultishellCore

extension AppModel {
  /// By the id `projects list` prints; see `ControlID`.
  func project(withControlID id: String) -> Project? {
    workspace.projects.first { ControlID.project($0.id) == id }
  }

  /// By the id `worktrees list` prints.
  func worktree(withControlID id: String) -> Worktree? {
    workspace.worktrees.first { ControlID.worktree($0.id) == id }
  }
}
