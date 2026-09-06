import MultishellCore

/// A project removal waiting on the confirmation dialog. Removing a project
/// closes every live terminal in its worktrees and there is no undo, so it
/// asks first, the way worktree removal does.
///
/// The settings window is its own window, so the dialog has to be shown
/// there when the request came from it; `source` says which window presents.
public struct PendingProjectRemoval: Identifiable, Equatable, Sendable {
  public enum Source: Equatable, Sendable {
    case workspace
    case settings
  }

  public let project: Project
  public let source: Source

  public init(project: Project, source: Source) {
    self.project = project
    self.source = source
  }

  public var id: String { project.id }

  public var title: String { "Remove project \(project.name)?" }

  /// Names what goes and what stays. The repository is never touched: the
  /// project is a sidebar entry, and its worktrees are git's.
  public static func message(liveTerminals: Int) -> String {
    var notes = ["Takes the project and its worktrees out of the sidebar."]
    if liveTerminals > 0 {
      notes.append("\(Wording.count(liveTerminals, "open terminal")) will be closed.")
    }
    notes.append(
      "Nothing on disk is touched; the repository and its worktrees stay where they are.")
    return notes.joined(separator: " ")
  }
}
