import MultishellCore

/// A project removal waiting on the confirmation dialog. Removing a project
/// closes every live terminal in its worktrees and there is no undo, so it
/// asks first, the way worktree removal does.
///
/// The settings window is its own `Window`, so the dialog has to be shown
/// there when the request came from it; `source` says which window presents.
struct PendingProjectRemoval: Identifiable, Equatable {
  enum Source: Equatable {
    case workspace
    case settings
  }

  let project: Project
  let source: Source

  var id: String { project.id }

  var title: String { "Remove project \(project.name)?" }

  /// Names what goes and what stays. The repository is never touched: the
  /// project is a sidebar entry, and its worktrees are git's.
  static func message(liveTerminals: Int) -> String {
    var notes = ["Takes the project and its worktrees out of the sidebar."]
    if liveTerminals > 0 {
      notes.append(
        "\(liveTerminals) open terminal\(liveTerminals == 1 ? "" : "s") will be closed.")
    }
    notes.append(
      "Nothing on disk is touched; the repository and its worktrees stay where they are.")
    return notes.joined(separator: " ")
  }
}
