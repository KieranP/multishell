import MultishellCore

extension AppModel {
  /// The worktree whose terminals are on screen: the selected one unless a
  /// cover hides them. Everything acting on the tab in front asks here.
  var worktreeInView: Worktree? {
    detailCover == nil ? workspace.selectedWorktree : nil
  }

  /// `worktreeInView`'s id, for asking without a lookup.
  var worktreeIDInView: Worktree.ID? {
    detailCover == nil ? workspace.selectedWorktreeID : nil
  }

  /// The focused group's tab in `worktreeInView`, which Cmd+W, find and seen act on.
  var tabInView: TerminalTab? {
    worktreeInView.flatMap { workspace.activeTab(in: $0.id) }
  }

  /// The pane the keyboard goes to: the selected worktree's active tab's
  /// focused pane, with the board hidden. One in the window, not one per
  /// group: a surface reports focus back, so two would trade it.
  public func isFocusedPane(_ id: TerminalSession.ID) -> Bool {
    tabInView?.focusedSessionID == id
  }

  /// The pane is on screen: its worktree selected and its tab shown, asked
  /// of every group. What holds a banner back, saying nothing about focus.
  func isPaneInView(_ id: TerminalSession.ID) -> Bool {
    // A cover fills the detail area, so no pane is on screen behind it, and
    // a board card would reach Idle having never passed through Done.
    guard let worktree = worktreeIDInView else { return false }
    return workspace.shownTabs(in: worktree).contains { $0.root.contains(id) }
  }

  /// Whether the detail area is this worktree's, which its sidebar row and
  /// pane rows follow: selected, and not covered.
  public func isInView(_ worktree: Worktree) -> Bool {
    worktreeIDInView == worktree.id
  }
}
