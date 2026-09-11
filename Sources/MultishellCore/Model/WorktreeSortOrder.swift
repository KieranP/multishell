import Foundation

/// The order a project's worktree rows are listed in. A raw value here is
/// committed to repositories, so add cases but never rename one.
public enum WorktreeSortOrder: String, Codable, Hashable, Sendable, CaseIterable {
  /// By the name the row shows: the user's own where they gave one, else
  /// the branch.
  case alphabetical
  /// By when the worktree's directory was made; see `Worktree.createdAt`.
  case createdNewestFirst
  case createdOldestFirst
  /// By the last commit on the branch, which is what "worked on recently"
  /// means. A detached or bare worktree has no branch to date.
  case committedNewestFirst
  case committedOldestFirst

  /// Alphabetical, the only order reading the same on every machine: a
  /// copied directory has lost its creation date.
  public static let `default` = WorktreeSortOrder.alphabetical

  /// Each label names its date then its direction, so five read as one set.
  /// `Name` carries none, its order needing no telling.
  public var displayName: String {
    switch self {
    case .alphabetical: t("sort.alphabetical")
    case .createdNewestFirst: t("sort.created-newest-first")
    case .createdOldestFirst: t("sort.created-oldest-first")
    case .committedNewestFirst: t("sort.committed-newest-first")
    case .committedOldestFirst: t("sort.committed-oldest-first")
    }
  }
}
