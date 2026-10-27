import MultishellCore

/// Where a quick switcher row goes when chosen.
public enum QuickSwitcherTarget: Hashable, Sendable {
  /// A menu bar item, by its titles from the bar down.
  case command(path: [String])
  /// A file of the selected worktree, opened as a file tab.
  case file(path: String, worktreeID: Worktree.ID)
  case fileTab(FileTab.ID)
  /// A pane of a terminal tab, an agent's or a shell's.
  case pane(TerminalSession.ID)
  case project(Project.ID)
  case worktree(Worktree.ID)
}
