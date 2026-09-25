import Foundation

/// What a flag line may stand in for, written `{{branch}}`. The whole list,
/// and the only place one is spelled; see Docs/design/agents.md.
public enum AgentPlaceholder: String, CaseIterable, Sendable {
  /// The branch, or the short SHA when detached.
  case branch
  /// What the sidebar calls the worktree: the user's name for it, else its
  /// branch.
  case worktree
  /// The worktree's directory.
  case worktreePath = "worktree_path"
  /// The repository's folder name.
  case project
  /// The repository root.
  case projectPath = "project_path"

  var token: String { "{{\(rawValue)}}" }

  /// What a custom command reads the value from, named as the hook
  /// variables are where one means the same.
  var variable: String {
    switch self {
    case .branch: "MULTISHELL_BRANCH"
    case .worktree: "MULTISHELL_WORKTREE_NAME"
    case .worktreePath: "MULTISHELL_WORKTREE_PATH"
    case .project: "MULTISHELL_PROJECT_NAME"
    case .projectPath: "MULTISHELL_PROJECT_PATH"
    }
  }

  /// `worktreeName` is what the sidebar shows, `Workspace.displayName(of:)`,
  /// which the worktree record cannot answer on its own.
  public static func values(
    project: Project, worktree: Worktree, worktreeName: String
  ) -> [AgentPlaceholder: String] {
    var values: [AgentPlaceholder: String] = [:]
    for placeholder in allCases {
      values[placeholder] =
        switch placeholder {
        case .branch: worktree.branch ?? worktree.name
        case .worktree: worktreeName
        case .worktreePath: worktree.path.path
        case .project: project.name
        case .projectPath: project.path.path
        }
    }
    return values
  }
}
