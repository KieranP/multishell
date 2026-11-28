extension ProjectSettings {
  /// The project's value where it has one, the default otherwise, either trimmed.
  func effectiveWorktreeSettings(defaults: WorktreeSettings) -> WorktreeSettings {
    WorktreeSettings(
      worktreeDirectory: worktreeDirectory ?? defaults.worktreeDirectory,
      branchPrefix: branchPrefix ?? defaults.branchPrefix,
    )
    .trimmed
  }
}
