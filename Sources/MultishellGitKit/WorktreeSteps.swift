import MultishellCore

/// The stages of a create, in order, for a sheet to show while it waits. A
/// hook stage is reported only when that hook has a script.
public enum WorktreeCreationStep: Sendable, Equatable {
  case preCreateHook
  case addingWorktree
  case postCreateHook
}

/// The stages of a remove, in order. A hook stage is reported only when that
/// hook has a script; the branch stage only when the branch is to go.
public enum WorktreeRemovalStep: Sendable, Equatable {
  case preDeleteHook
  /// The directory to the Trash, then `git worktree prune`.
  case removingWorktree
  case postDeleteHook
  case deletingBranch

  /// Where a remove of this worktree under these settings starts, so a
  /// caller can show the first stage before the first report arrives.
  public static func first(for project: Project) -> WorktreeRemovalStep {
    WorktreeHooks.hasScript(project.settings.preDeleteHook) ? .preDeleteHook : .removingWorktree
  }
}
