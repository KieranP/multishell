import Foundation
import MultishellCore

/// What a project hook is told, and what the settings panel calls each
/// variable. One list, so neither can gain a case without the other.
public enum HookVariable: CaseIterable, Sendable {
  case projectPath
  case projectName
  case worktreePath
  case branch

  /// Spelled by the placeholder meaning the same, so a custom command and a
  /// hook read one name.
  public var name: String {
    switch self {
    case .projectPath: WorktreePlaceholder.projectPath.variable
    case .projectName: WorktreePlaceholder.project.variable
    case .worktreePath: WorktreePlaceholder.worktreePath.variable
    case .branch: WorktreePlaceholder.branch.variable
    }
  }

  /// The one-line description the Hooks tab shows beside the name.
  public var meaning: String {
    switch self {
    case .projectPath: t("hook-variable.project-path")
    case .projectName: t("hook-variable.project-name")
    case .worktreePath: t("hook-variable.worktree-path")
    case .branch: t("hook-variable.branch")
    }
  }

  static func environment(
    project: Project, worktreePath: URL, branch: String
  ) -> [String: String] {
    var environment: [String: String] = [:]
    for variable in allCases {
      environment[variable.name] =
        switch variable {
        case .projectPath: project.path.path
        case .projectName: project.name
        case .worktreePath: worktreePath.path
        case .branch: branch
        }
    }
    return environment
  }
}
