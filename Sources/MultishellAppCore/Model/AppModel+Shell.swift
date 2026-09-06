import Foundation
import MultishellCore

// MARK: - Default shell and what selecting does

extension AppModel {
  public func setDefaultShell(_ id: String?) {
    store.setDefaultShell(id == ShellCatalogue.loginShellID ? nil : id)
  }

  public func setCustomShellPath(_ path: String) {
    store.setCustomShellPath(path)
  }

  /// What the typed custom path will do, for the caption under its field:
  /// nothing to say when it names an executable.
  public var customShellPathProblem: String? {
    let path = workspace.customShellPath.trimmingCharacters(in: .whitespaces)
    if path.isEmpty { return "Blank, so tabs run the login shell, \(shellDetection.loginShell)." }
    if !FileManager.default.isExecutableFile(atPath: path) {
      return "Nothing executable at that path; a new tab would fail to start."
    }
    return nil
  }

  public func setOpensTerminalOnSelect(_ enabled: Bool) {
    store.setOpensTerminalOnSelect(enabled)
  }

  /// The shell a tab in this worktree runs: the project's override, else
  /// the global choice, else `$SHELL`.
  public func shellPath(forWorktree id: Worktree.ID) -> String {
    guard let worktree = workspace.worktree(id), let project = workspace.project(worktree.projectID)
    else { return ShellCatalogue.loginShellPath() }
    return workspace.defaultShell(for: project) ?? ShellCatalogue.loginShellPath()
  }

  /// What the dropdown and captions call a stored shell.
  public func shellDisplayName(_ id: String?) -> String {
    ShellCatalogue.displayName(
      id, customPath: workspace.customShellPath, loginShell: shellDetection.loginShell)
  }
}
