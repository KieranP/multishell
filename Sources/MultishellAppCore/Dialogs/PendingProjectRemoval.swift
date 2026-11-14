import MultishellCore

/// A project removal waiting on its dialog: it closes every live terminal in
/// the project and has no undo. `window` says which window presents.
public struct PendingProjectRemoval: Identifiable, Equatable, Sendable {
  public let project: Project
  let window: DialogWindow

  public var id: String { project.id }

  public var title: String { t("project-removal.title", project.name) }

  /// Names what goes and what stays. The repository is never touched: the
  /// project is a sidebar entry, and its worktrees are git's.
  static func message(liveTerminals: Int) -> String {
    var notes = [t("project-removal.takes")]
    if liveTerminals > 0 {
      notes.append(t("removal.terminals-closed", liveTerminals))
    }
    notes.append(t("project-removal.nothing-on-disk"))
    return notes.joined(separator: " ")
  }
}
