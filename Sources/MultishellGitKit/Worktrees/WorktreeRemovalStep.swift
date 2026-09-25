import MultishellCore

/// The stages of a remove, in order. A hook stage is reported only when that
/// hook has a script; the branch stage only when the branch is to go.
public enum WorktreeRemovalStep: Sendable, Equatable {
  case preDeleteHook
  /// The directory to the Trash, then its record forgotten.
  case removingWorktree
  case postDeleteHook
  case deletingBranch

  /// Where a remove of this worktree under these settings starts, so a
  /// caller can show the first stage before the first report arrives.
  public static func first(for project: Project) -> WorktreeRemovalStep {
    WorktreeHooks.hasScript(.preDelete, in: project.settings) ? .preDeleteHook : .removingWorktree
  }
}
