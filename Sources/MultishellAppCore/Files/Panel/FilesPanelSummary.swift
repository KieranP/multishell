import MultishellGitKit

/// What the panel's footer counts: the badge's own numbers, or Branch's, so
/// the two never disagree, and what the listing left out.
public struct FilesPanelSummary: Equatable, Sendable {
  public let changedFiles: Int
  public let insertions: Int
  public let deletions: Int
  let comparison: ChangeComparison
  /// New files counted but past the panel's cap on drawing them, none where the list is empty.
  let unlistedUntrackedFiles: Int
  /// The index tracks more than the panel lists.
  let isTrackedListCapped: Bool

  init(
    tree: FileTree,
    status: WorktreeStatus?,
    comparison: ChangeComparison,
    tracked: TrackedFiles,
  ) {
    changedFiles = tree.changedFileCount
    self.comparison = comparison
    switch comparison {
    case .head:
      insertions = status?.insertions ?? 0
      deletions = status?.deletions ?? 0
      unlistedUntrackedFiles = status?.unlistedUntrackedFiles ?? 0

    case .noBase, .unread, .unreadable:
      insertions = 0
      deletions = 0
      unlistedUntrackedFiles = 0

    case .branch(let changes):
      insertions = changes.insertions
      deletions = changes.deletions
      unlistedUntrackedFiles = changes.mergeBase == nil ? 0 : status?.unlistedUntrackedFiles ?? 0
    }
    isTrackedListCapped = tracked.isCapped
  }
}
