import Foundation

/// What an editor is handed: a worktree's directory, from Open in Editor, or
/// one of its text files, from a clicked link or Open in Editor on a file.
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
