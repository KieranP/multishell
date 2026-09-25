import Foundation
import MultishellCore

extension AppModel {
  public func setPreferredShell(_ id: String?) {
    store.setPreferredShell(id == ShellCatalogue.loginShellID ? nil : id)
  }

  public func setCustomShellPath(_ path: String) {
    store.setCustomShellPath(path)
  }

  /// Whether the shell picker is on the custom path, whose field shows.
  public var usesCustomShell: Bool {
    workspace.preferredShellID == ShellCatalogue.customID
  }

  /// What the typed custom path will do, for the caption under its field:
  /// nothing to say when it names an executable.
  public var customShellPathProblem: String? {
    let path = workspace.customShellPath.trimmingCharacters(in: .whitespaces)
    if path.isEmpty { return t("shell.path-blank", shellDetection.loginShell) }
    if !FileManager.default.isExecutableFile(atPath: path) {
      return t("shell.path-not-executable")
    }
    return nil
  }

  /// The shell a tab in this worktree runs: the project's override, else
  /// the global choice, else `$SHELL`.
  func shellPath(forWorktree id: Worktree.ID) -> String {
    guard let worktree = workspace.worktree(id) else { return ShellCatalogue.loginShellPath() }
    return shellPath(for: worktree)
  }

  /// The same for a worktree in hand, which may have left the list since.
  func shellPath(for worktree: Worktree) -> String {
    workspace.project(worktree.projectID).flatMap(workspace.effectiveShellPath)
      ?? ShellCatalogue.loginShellPath()
  }

  /// What the dropdown and captions call a stored shell.
  public func shellDisplayName(_ id: String?) -> String {
    ShellCatalogue.displayName(
      id, customPath: workspace.customShellPath, loginShell: shellDetection.loginShell)
  }
}
