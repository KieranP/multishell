/// Every path a worktree's index tracks, for the Files panel's All list.
public struct TrackedFiles: Equatable, Sendable {
  public static let empty = Self(
    paths: [],
    submodulePaths: [],
    notCheckedOutPaths: [],
    isCapped: false,
  )

  /// Relative to the worktree, a submodule's own path among them.
  public let paths: [String]
  /// The submodules among `paths`: gitlinks, which the panel draws as folders.
  public let submodulePaths: Set<String>
  /// Left off disk by a sparse checkout: listed greyed, and not opened.
  public let notCheckedOutPaths: Set<String>
  /// The index tracks more than `WorktreeGit.trackedPathLimit`, the rest left out.
  public let isCapped: Bool
}
