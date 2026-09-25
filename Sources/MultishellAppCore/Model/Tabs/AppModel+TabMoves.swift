import MultishellCore

extension AppModel {
  /// Moves `id` beside `target`, possibly in another group. A move leaving
  /// the strip reading the same writes nothing, the shuffle having done it.
  /// `false` where either tab has gone or they sit in different worktrees.
  @discardableResult
  func moveTab(
    _ id: TerminalTab.ID, _ placement: TerminalTab.Placement, anchor target: TerminalTab.ID
  ) -> Bool {
    guard changesTheStrip(id, placement, target) else { return true }
    guard store.moveTab(id, placement, target) else { return false }
    // The drop activates the tab in its new group, so without this the engine
    // keeps focus on the one now hidden behind it.
    reconcileSessions(takingFocus: true)
    return true
  }

  /// A tab landing in another group always changes something, if only
  /// which group it is in. Inside one group it is a question of order.
  private func changesTheStrip(
    _ id: TerminalTab.ID, _ placement: TerminalTab.Placement, _ target: TerminalTab.ID
  ) -> Bool {
    guard
      let moving = workspace.tab(id), let anchor = workspace.tab(target),
      moving.groupID == anchor.groupID
    else { return true }
    return TabShuffle.reorders(
      id, placement, of: target, in: workspace.tabs(in: moving.groupID).map(\.id))
  }

  /// A tab dragged onto a worktree's row, shells and all, the destination
  /// turned to. `false` where the move cannot happen; see tabs-and-groups.md.
  @discardableResult
  func moveTab(_ id: TerminalTab.ID, to worktreeID: Worktree.ID) -> Bool {
    guard
      let source = workspace.tab(id)?.worktreeID, source != worktreeID, !isBusy(source),
      let worktree = workspace.worktree(worktreeID), requireShellReady(worktree),
      store.moveTab(id, to: worktreeID)
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
    guard let group = focusedGroup, let tab = workspace.activeTab(in: group) else { return }
    moveTab(tab.id, .after, toNewGroupOf: group.id)
  }

  /// A tab dropped on the band down a group's edge, or the menu item above.
  /// `false` when nothing moved, so the drag springs back.
  @discardableResult
  public func moveTab(
    _ id: TerminalTab.ID, _ placement: TerminalTab.Placement, toNewGroupOf group: TabGroup.ID
  ) -> Bool {
    guard store.moveTabToNewGroup(id, placement, of: group) != nil else { return false }
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
