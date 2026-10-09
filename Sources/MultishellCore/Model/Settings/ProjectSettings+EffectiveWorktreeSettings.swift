import Foundation

extension ProjectSettings {
  /// The project's value where it has one, the default otherwise.
  func effectiveWorktreeSettings(defaults: WorktreeSettings) -> WorktreeSettings {
    WorktreeSettings(
      worktreeDirectory: worktreeDirectory?.trimmingCharacters(in: .whitespaces)
        ?? defaults.worktreeDirectory,
      branchPrefix: branchPrefix?.trimmingCharacters(in: .whitespaces) ?? defaults.branchPrefix,
    )
  }
}
