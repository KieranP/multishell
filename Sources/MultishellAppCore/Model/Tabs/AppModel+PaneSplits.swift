import MultishellCore

extension AppModel {
  /// The menu items name no group and split the focused one's active tab;
  /// a strip's own buttons name theirs, as New Tab does, and focus it.
  public func splitActivePane(_ axis: SplitAxis, in group: TabGroup.ID? = nil) {
    guard let worktree = requireWorktreeForShell(), let tab = tabToSplit(in: group, of: worktree)
    else { return }
    store.splitFocusedPane(of: tab.id, axis: axis)
    // The new pane takes focus in its tab, so its group must too, else the
    // keyboard stays in another group. Asked first, or autosave re-arms for nothing.
    if workspace.focusedGroup(in: worktree.id)?.id != tab.groupID {
      store.focusGroup(tab.groupID)
    }
    reconcileSessions(takingFocus: true)
  }

  /// A group named by a strip's own button, which has to be one of this
  /// worktree's, or the focused group's tab where none is named.
  private func tabToSplit(in group: TabGroup.ID?, of worktree: Worktree) -> TerminalTab? {
    guard let group else { return workspace.activeTab(in: worktree.id) }
    guard let named = workspace.group(group), named.worktreeID == worktree.id else { return nil }
    return workspace.shownTab(ofGroup: named)
  }

  public func setSplitWeights(_ weights: [Double], at path: [Int], ofTab tabID: TerminalTab.ID) {
    store.setSplitWeights(weights, at: path, ofTab: tabID)
  }
}
