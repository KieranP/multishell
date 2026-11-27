import MultishellCore

// Declared order is the order the steps run in.
// swiftlint:disable sorted_enum_cases
/// The steps of a remove, in order. A hook step is reported only when that
/// hook has a script; the branch step only when the branch is to go.
public enum WorktreeRemovalStep: Sendable, Equatable {
  case preDeleteHook
  /// The directory to the Trash, then its record forgotten.
  case removingWorktree
  case postDeleteHook
  case deletingBranch

  /// Where a remove of a worktree in this project starts, so a
  /// caller can show the first step before the first report arrives.
  public static func first(for project: Project) -> Self {
    WorktreeHooks.hasScript(.preDelete, in: project.settings) ? .preDeleteHook : .removingWorktree
  }
}
// swiftlint:enable sorted_enum_cases
