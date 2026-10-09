import MultishellCore

/// What fills the detail area beside the sidebar. The three worktree cases
/// draw its header above them.
public enum DetailContent: Equatable, Sendable {
  case cover(DetailCover)
  case noSelection(hasProjects: Bool)
  case noTabs(Worktree)
  /// A create has no terminals yet, and a remove is about to close them.
  case operation(Worktree, WorktreeOperation)
  case tabGroups(Worktree)
}
