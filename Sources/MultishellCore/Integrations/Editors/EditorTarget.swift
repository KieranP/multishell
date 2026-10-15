import Foundation

/// What an editor is handed: a worktree's directory, from Open in Editor, or
/// a text file a link clicked in one of its panes names.
public enum EditorTarget: Sendable {
  case file(URL)
  case worktree(URL)

  public var path: URL {
    switch self {
    case .file(let url), .worktree(let url): url
    }
  }

  /// What a custom editor command reads `{path}` from.
  var pathVariable: String {
    switch self {
    case .file: "MULTISHELL_FILE_PATH"
    case .worktree: WorktreePlaceholder.worktreePath.variable
    }
  }
}
