import AppKit
import MultishellCore

// MARK: - Default shell and what selecting does

extension AppModel {
  func setDefaultShell(_ id: String?) {
    store.setDefaultShell(id == ShellCatalogue.loginShellID ? nil : id)
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
    return id
  }
}
