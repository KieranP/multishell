import MultishellCore
import MultishellGitKit

extension NewWorktreeDraft {
  /// What the sheet says beside its spinner while a create runs, a hook
  /// taking a minute. `nil` is the tail: the refresh and the select.
  public static func progressText(for step: WorktreeCreationStep?) -> String {
    switch step {
    case .preCreateHook: t("step.pre-create-hook")
    case .addingWorktree: t("step.adding-worktree")
    case nil: t("step.creating-worktree")
    }
  }

  /// Picker labels. A folder name alone, unless another project shares it,
  /// when the path tells them apart.
  public static func labels(for projects: [Project]) -> [Project.ID: String] {
    var count: [String: Int] = [:]
    for project in projects { count[project.name, default: 0] += 1 }
    // Repair keeps identities unique; a repeat here must still not trap.
    return Dictionary(
      keepingFirst:
        projects.map { project in
          let label =
            count[project.name] == 1
            ? project.name
            : "\(project.name)  (\(project.path.path.abbreviatingHomeDirectory()))"
          return (project.id, label)
        })
  }
}
