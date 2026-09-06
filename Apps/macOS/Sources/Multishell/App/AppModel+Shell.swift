import AppKit
import Foundation
import MultishellCore

// MARK: - Default shell and what selecting does

extension AppModel {
  func setDefaultShell(_ id: String?) {
    store.setDefaultShell(id == ShellCatalogue.loginShellID ? nil : id)
  }

  func setCustomShellPath(_ path: String) {
    store.setCustomShellPath(path)
  }

  /// What the typed custom path will do, for the caption under its field:
  /// nothing to say when it names an executable.
  var customShellPathProblem: String? {
    let path = workspace.customShellPath.trimmingCharacters(in: .whitespaces)
    if path.isEmpty { return "Blank, so tabs run the login shell, \(shellDetection.loginShell)." }
    if !FileManager.default.isExecutableFile(atPath: path) {
      return "Nothing executable at that path; a new tab would fail to start."
    }
    return nil
  }

  func setOpensTerminalOnSelect(_ enabled: Bool) {
    store.setOpensTerminalOnSelect(enabled)
  }

  /// The shell a tab in this worktree runs: the project's override, else
  /// the global choice, else `$SHELL`.
  func shellPath(forWorktree id: Worktree.ID) -> String {
    guard let worktree = workspace.worktree(id), let project = workspace.project(worktree.projectID)
    else { return ShellCatalogue.loginShellPath() }
    return workspace.defaultShell(for: project) ?? ShellCatalogue.loginShellPath()
  }

  /// What the dropdown and captions call a stored shell.
  func shellDisplayName(_ id: String?) -> String {
    guard let id, id != ShellCatalogue.loginShellID else {
      return "the login shell (\(shellDetection.loginShell))"
    }
    guard id == ShellCatalogue.customID else { return id }
    let path = workspace.customShellPath.trimmingCharacters(in: .whitespaces)
    return path.isEmpty ? "the custom path, blank, so the login shell" : "the custom path \(path)"
  }
}
