import MultishellCore

/// What choosing a quick switcher row came to, which a request answers by.
enum QuickSwitcherChoice {
  case done
  /// A menu item a request chose, and the menu's answer once it has run.
  case menuItem(path: [String], Task<PlatformMenuOutcome, Never>)
  /// A menu item a request chose that the menu would refuse now, the switcher left up.
  case menuItemRefused(path: [String], PlatformMenuOutcome)
  /// The switcher was already down, so nothing was chosen.
  case notUp
  /// A file being opened as a tab, `nil` once it would not open.
  case openingFile(path: String, worktree: Worktree.ID, Task<FileTab?, Never>)
  /// A project row whose project has no worktree to show.
  case projectWithNoWorktree(Project.ID)
  /// The row led to a worktree, tab or pane gone since it was listed.
  case rowGone
  /// Its worktree could not be selected: being created or removed, or its folder gone.
  case worktreeNotReady(Worktree.ID)
}
