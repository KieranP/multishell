import MultishellCore

extension AppModel {
  /// Moves `id` beside `anchor`, possibly in another group; `false` where either
  /// has gone or they sit in different worktrees. A no-op move writes nothing.
  @discardableResult
  func moveTab(
    _ id: TerminalTab.ID, _ placement: TerminalTab.Placement, anchor: TerminalTab.ID
  ) -> Bool {
    guard changesTheStrip(id, placement, anchor) else { return true }
    guard store.moveTab(id, placement, anchor: anchor) else { return false }
    // The drop activates the tab in its new group, so without this the engine
    // keeps focus on the one now hidden behind it.
    reconcileSessions(takingFocus: true)
    return true
  }

  /// A tab landing in another group always changes something, if only
  /// which group it is in. Inside one group it is a question of order.
  private func changesTheStrip(
    _ id: TerminalTab.ID, _ placement: TerminalTab.Placement, _ anchor: TerminalTab.ID
  ) -> Bool {
    guard
      let moving = workspace.tab(id), let anchorTab = workspace.tab(anchor),
      moving.groupID == anchorTab.groupID
    else { return true }
    return TabShuffle.reorders(
      id, placement, of: anchor, in: workspace.tabs(inGroup: moving.groupID).map(\.id))
  }

  /// A tab dragged onto a worktree's row, shells and all, the destination
  /// turned to. `false` where the move cannot happen; see tabs-and-groups.md.
  @discardableResult
  func moveTab(_ id: TerminalTab.ID, toWorktree worktreeID: Worktree.ID) -> Bool {
    guard
      let source = workspace.tab(id)?.worktreeID, source != worktreeID, !isBusy(source),
      let worktree = workspace.worktree(worktreeID), requireShellReady(worktree),
      store.moveTab(id, toWorktree: worktreeID)
    else { return false }
    // Warmed here, not left to the selection: the shells are live, and a
    // cold destination is one the next reconcile would close them for.
    warmWorktrees.insert(worktreeID)
    select(worktree)
    return true
  }

  /// Move Tab to New Group: the tab in front of the user gets a group of
  /// its own, to the right of the group it was in.
  public func moveActiveTabToNewGroup() {
    guard let group = focusedGroup, let tab = workspace.shownTab(in: group) else { return }
    moveTab(tab.id, .after, toNewGroupOf: group.id)
  }

  /// A tab dropped on the band down a group's edge, or the menu item above.
  /// `false` when nothing moved, so the drag springs back.
  @discardableResult
  public func moveTab(
    _ id: TerminalTab.ID, _ placement: TerminalTab.Placement, toNewGroupOf group: TabGroup.ID
  ) -> Bool {
    guard store.moveTab(id, placement, toNewGroupOf: group) != nil else { return false }
    reconcileSessions(takingFocus: true)
    return true
  }

  /// A tab dropped on a group's strip clear of its tabs: it lands last
  /// there. A drop on a tab goes through `moveTab(_:_:anchor:)` instead.
  @discardableResult
  func moveTab(_ id: TerminalTab.ID, toEndOf group: TabGroup.ID) -> Bool {
    guard store.moveTab(id, toEndOf: group) else { return false }
    reconcileSessions(takingFocus: true)
    return true
  }
}
