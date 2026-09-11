import Foundation

/// The order a project's worktree rows are listed in.
///
/// The main worktree keeps first place whatever this says; `WorktreeOrder`
/// applies the rule alongside this choice.
///
/// A raw value here is committed to repositories, not only written to the
/// local `state.json`: a team may ship an order in `.multishell.json`. So a
/// case may be added and its label reworded, but a raw value must not be
/// renamed — someone else's committed file would quietly stop being read
/// and their sidebar would fall back to the default with nothing said.
public enum WorktreeSortOrder: String, Codable, Hashable, Sendable, CaseIterable {
  /// By the name the row shows: the user's own where they gave one, else
  /// the branch.
  case alphabetical
  /// By when the worktree's directory was made; see `Worktree.createdAt`.
  case createdNewestFirst
  case createdOldestFirst
  /// By the last commit on the worktree's branch, which is what "worked on
  /// recently" means to anyone who lives in worktrees. A detached or bare
  /// worktree has no branch to date.
  case committedNewestFirst
  case committedOldestFirst

  /// Alphabetical, because it is the only one of them that reads the same
  /// on every machine: a creation date comes from the filesystem, and a
  /// directory that was copied rather than created has lost it.
  public static let `default` = WorktreeSortOrder.alphabetical

  /// Each label names the date it sorts by and then the direction, in the
  /// same shape every time, so a picker of five reads as one set. `Name`
  /// carries no direction: it is the only key that is not a date, and the
  /// only one with an order nobody has to be told.
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
