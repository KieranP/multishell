import MultishellCore

extension AppModel {
  /// The project a command should act on while nothing else names one: the
  /// worktree in view's, or the only project. The board names none.
  var projectInView: Project? { projectOrOnlyProject(of: worktreeInView) }

  func projectOrOnlyProject(of worktree: Worktree?) -> Project? {
    if let worktree { return workspace.project(worktree.projectID) }
    return workspace.projects.count == 1 ? workspace.projects.first : nil
  }

  /// The workspace's copy, or `project` once it has gone: a caller's copy can
  /// predate a write it would then undo.
  func currentCopy(of project: Project) -> Project {
    workspace.project(project.id) ?? project
  }
}
