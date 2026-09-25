import MultishellCore

extension AppModel {
  public func activate(_ tab: TerminalTab) {
    store.activateTab(tab.id)
    reconcileSessions(takingFocus: true)
  }

  /// A pane of the selected worktree brought on screen with the keyboard,
  /// from its sidebar row.
  public func show(pane id: TerminalSession.ID) {
    guard let tab = workspace.tab(owning: id) else { return }
    show(pane: id, in: tab)
  }

  /// The reconcile hands the keyboard to the active tab's focused pane,
  /// which is this one now, so nothing more is needed to land in it.
  func show(pane id: TerminalSession.ID, in tab: TerminalTab) {
    store.activateTab(tab.id)
    store.focusSession(id)
    reconcileSessions(takingFocus: true)
  }

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
    return workspace.activeTab(in: named)
  }

  public func setSplitWeights(_ weights: [Double], at path: [Int], ofTab tabID: TerminalTab.ID) {
    store.setSplitWeights(weights, at: path, ofTab: tabID)
  }

  public func activateNextTab() { activateAdjacentTab(.next) }
  public func activatePreviousTab() { activateAdjacentTab(.previous) }

  /// The tab one place along the strip, wrapping at either end.
  private func activateAdjacentTab(_ direction: CycleDirection) {
    guard
      let worktree = worktreeInView?.id,
      let current = workspace.activeTab(in: worktree),
      let next = direction == .next
        ? workspace.tab(after: current.id) : workspace.tab(before: current.id)
    else { return }
    activate(next)
  }

  /// What the tab strip shows: the user's name, else what the shell last
  /// reported, else the tab's starting title.
  public func title(of tab: TerminalTab) -> String {
    tab.customTitle ?? sessionTitles[tab.focusedSessionID] ?? workspace.title(of: tab)
  }

  /// One pane's, a split holding several: the user's name for the tab, else
  /// what this pane's shell last reported, else its starting title.
  public func title(ofPane session: TerminalSession, in tab: TerminalTab) -> String {
    tab.customTitle ?? sessionTitles[session.id] ?? session.displayTitle
  }

  /// Whether the tab's focused pane wears the theme's ring: only where there
  /// is another pane on screen to tell it from, in a split or a second group.
  public func showsFocusRing(in tab: TerminalTab) -> Bool {
    tab.isSplit || workspace.groups(in: tab.worktreeID).count > 1
  }
}
