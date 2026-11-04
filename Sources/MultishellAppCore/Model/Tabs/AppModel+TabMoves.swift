import MultishellCore

extension AppModel {
  /// Moves `id` beside `anchor`, possibly in another group; `false` where either
  /// has gone or they sit in different worktrees. A no-op move writes nothing.
  @discardableResult
  func moveTab(
    _ id: WorkspaceTab.ID,
    _ placement: WorkspaceTab.Placement,
    anchor: WorkspaceTab.ID,
    takingFocus: Bool = true,
  ) -> Bool {
    guard changesTheStrip(id, placement, anchor) else { return true }
    guard store.moveTab(id, placement, anchor: anchor) else { return false }
    // The drop activates the tab in its new group, so without this the engine
    // keeps focus on the one now hidden behind it.
    reconcileSessions(takingFocus: takingFocus)
    return true
  }

  /// A tab landing in another group always changes something, if only
  /// which group it is in. Inside one group it is a question of order.
  private func changesTheStrip(
    _ id: WorkspaceTab.ID,
    _ placement: WorkspaceTab.Placement,
    _ anchor: WorkspaceTab.ID,
  ) -> Bool {
    guard let group = workspace.sharedGroup(of: id, and: anchor) else { return true }
    return TabShuffle.reorders(
      id,
      placement,
      of: anchor,
      in: workspace.workspaceTabs(inGroup: group).map(\.id),
    )
  }

  /// A terminal tab dragged onto a worktree's row, shells and all; `false` where
  /// it cannot move, a file tab's always. See tabs-and-groups.md.
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
    guard let group = focusedGroup, let tab = workspace.shownWorkspaceTab(ofGroup: group)
    else { return }
    moveTab(tab.id, .after, toNewGroupOf: group.id)
  }

  /// Whether Move Tab to New Group can take a tab in this group: a group's
  /// only tab, of either kind, has no group to leave, and the store refuses it.
  public func canMoveTabToNewGroup(from group: TabGroup.ID) -> Bool {
    workspace.workspaceTabs(inGroup: group).count > 1
  }

  /// A tab dropped on the band down a group's edge, or the menu item above.
  /// `false` when nothing moved, so the drag springs back.
  @discardableResult
  public func moveTab(
    _ id: WorkspaceTab.ID,
    _ placement: WorkspaceTab.Placement,
    toNewGroupOf group: TabGroup.ID,
    takingFocus: Bool = true,
  ) -> Bool {
    guard store.moveTab(id, placement, toNewGroupOf: group) != nil else { return false }
    reconcileSessions(takingFocus: takingFocus)
    return true
  }

  /// A tab dropped on a group's strip clear of its tabs: it lands last
  /// there. A drop on a tab goes through `moveTab(_:_:anchor:)` instead.
  @discardableResult
  func moveTab(_ id: WorkspaceTab.ID, toEndOf group: TabGroup.ID) -> Bool {
    guard store.moveTab(id, toEndOf: group) else { return false }
    reconcileSessions(takingFocus: true)
    return true
  }
}
