import Foundation
import MultishellCore
import MultishellGitKit

extension NewWorktreeDraft {
  /// The default button, naming the agent it starts. The custom command's
  /// own name is not a word to put on a button.
  public var createTitle: String {
    guard case .agent(let id, _)? = firstTab else { return t("sheet.create-worktree") }
    return id == AgentCatalogue.customID
      ? t("sheet.create-and-start-custom")
      : t("sheet.create-and-start", AgentCatalogue.displayName(id))
  }

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
        }
    )
  }
}
