import MultishellCore

extension AppModel {
  /// The worktree whose terminals are on screen: the selected one unless the
  /// board covers them. Everything acting on the tab in front asks here.
  var worktreeInView: Worktree? {
    showsAgentBoard ? nil : workspace.selectedWorktree
  }

  /// `worktreeInView`'s id, for asking without a lookup.
  var worktreeIDInView: Worktree.ID? {
    showsAgentBoard ? nil : workspace.selectedWorktreeID
  }

  /// The focused group's tab in `worktreeInView`, which Cmd+W, find and seen act on.
  var tabInView: TerminalTab? {
    worktreeInView.flatMap { workspace.activeTab(in: $0.id) }
  }

  /// The pane is on screen: its worktree selected and its tab shown, asked
  /// of every group. What holds a banner back, saying nothing about focus.
  func isPaneInView(_ id: TerminalSession.ID) -> Bool {
    // The board fills the detail area, so no pane is on screen behind it,
    // and a card would reach Idle having never passed through Done.
    guard let worktree = worktreeIDInView else { return false }
    return workspace.shownTabs(in: worktree).contains { $0.root.contains(id) }
  }

  /// Whether the detail area is this worktree's, which its sidebar row and
  /// pane rows follow: selected, and not covered by the board.
  public func isInView(_ worktree: Worktree) -> Bool {
    worktreeIDInView == worktree.id
  }
}
