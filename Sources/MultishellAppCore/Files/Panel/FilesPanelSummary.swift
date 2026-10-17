import MultishellGitKit

/// What the panel's footer counts: the badge's own numbers, so the two never
/// disagree, and what the listing left out.
public struct FilesPanelSummary: Equatable, Sendable {
  public let changedFiles: Int
  public let insertions: Int
  public let deletions: Int
  /// New files counted but past the panel's cap on drawing them.
  let unlistedUntrackedFiles: Int
  /// The index tracks more than the panel lists.
  let isTrackedListCapped: Bool

  init(tree: FileTree, status: WorktreeStatus?, tracked: TrackedFiles) {
    changedFiles = tree.changedFileCount
    insertions = status?.insertions ?? 0
    deletions = status?.deletions ?? 0
    unlistedUntrackedFiles = status?.unlistedUntrackedFiles ?? 0
    isTrackedListCapped = tracked.isCapped
  }
}
