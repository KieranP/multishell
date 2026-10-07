import MultishellCore

extension AppModel {
  /// Whether the tab's focused pane wears the theme's ring: only where there
  /// is another pane on screen to tell it from, in a split or a second group.
  public func showsFocusRing(in tab: TerminalTab) -> Bool {
    tab.isSplit || workspace.groups(in: tab.worktreeID).count > 1
  }
}
