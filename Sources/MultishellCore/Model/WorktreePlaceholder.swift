import Foundation

/// What an agent's flags or custom command may stand in for, written
/// `{{branch}}`; see Docs/design/agents.md. An editor line has only `{path}`.
public enum WorktreePlaceholder: String, CaseIterable, Sendable {
  /// The branch, or the short SHA when detached.
  case branch
  /// What the sidebar calls the worktree: the user's name for it, else its
  /// branch.
  case worktreeName = "worktree"
  /// The worktree's directory.
  case worktreePath = "worktree_path"
  /// The repository's folder name.
  case projectName = "project"
  /// The repository root.
  case projectPath = "project_path"

  var token: String { "{{\(rawValue)}}" }

  /// What a custom command reads the value from, and the hook variable
  /// meaning the same.
  public var variable: String {
    switch self {
    case .branch: "MULTISHELL_BRANCH"
    case .worktreeName: "MULTISHELL_WORKTREE_NAME"
    case .worktreePath: "MULTISHELL_WORKTREE_PATH"
    case .projectName: "MULTISHELL_PROJECT_NAME"
    case .projectPath: "MULTISHELL_PROJECT_PATH"
    }
  }

  /// `worktreeName` is what the sidebar shows, `Workspace.displayName(of:)`,
  /// which the worktree record cannot answer on its own.
  public static func values(
    project: Project, worktree: Worktree, worktreeName: String
  ) -> [WorktreePlaceholder: String] {
    var values: [WorktreePlaceholder: String] = [:]
    for placeholder in allCases {
      values[placeholder] =
        switch placeholder {
        case .branch: worktree.branch ?? worktree.name
        case .worktreeName: worktreeName
        case .worktreePath: worktree.path.path
        case .projectName: project.name
        case .projectPath: project.path.path
        }
    }
    return values
  }
}
