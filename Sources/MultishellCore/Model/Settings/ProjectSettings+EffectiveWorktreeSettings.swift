import Foundation

extension ProjectSettings {
  /// The project's value where it has one, the default otherwise, either trimmed:
  /// a space typed into a field would otherwise reach the branch name or path.
  func effectiveWorktreeSettings(defaults: WorktreeSettings) -> WorktreeSettings {
    WorktreeSettings(
      worktreeDirectory: (worktreeDirectory ?? defaults.worktreeDirectory)
        .trimmingCharacters(in: .whitespaces),
      branchPrefix: (branchPrefix ?? defaults.branchPrefix).trimmingCharacters(in: .whitespaces),
    )
  }
}
