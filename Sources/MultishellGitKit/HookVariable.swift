import Foundation
import MultishellCore

/// What a project hook is told about the worktree it surrounds, and what a
/// settings panel calls each variable.
///
/// One list for both, so a variable cannot reach a hook without the Hooks
/// tab naming it: adding a case here forces its meaning and its value.
public enum HookVariable: String, CaseIterable, Sendable {
  case projectPath = "MULTISHELL_PROJECT_PATH"
  case projectName = "MULTISHELL_PROJECT_NAME"
  case worktreePath = "MULTISHELL_WORKTREE_PATH"
  case branch = "MULTISHELL_BRANCH"

  public var name: String { rawValue }

  /// The one-line description the Hooks tab shows beside the name.
  public var meaning: String {
    switch self {
    case .projectPath: "Repository root"
    case .projectName: "Repository folder name"
    case .worktreePath: "The worktree created or removed"
    case .branch: "Its branch"
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
