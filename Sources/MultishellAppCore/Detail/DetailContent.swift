import MultishellCore

/// What fills the detail area beside the sidebar. The three worktree cases
/// draw its header above them.
public enum DetailContent: Equatable, Sendable {
  /// In place of the selected worktree's terminals, whose shells stay live.
  case agentBoard
  /// A create has no terminals yet, and a remove is about to close them.
  case operation(Worktree, WorktreeOperation)
  case tabGroups(Worktree)
  case noTabs(Worktree)
  case noSelection(hasProjects: Bool)
}
