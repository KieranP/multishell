import MultishellCore

/// A worktree's terminal area is one or more columns of tabs. All layout, so
/// none of it asks whether a shell could start.
extension AppModel {
  /// The column the keystrokes go to, which is what the menu items and the
  /// tab-strip chrome are drawn from.
  public var focusedGroup: TabGroup? {
    worktreeInView.flatMap { workspace.focusedGroup(in: $0.id) }
  }

  /// A click anywhere in a column's strip. The pane keeps whatever focus it
  /// had inside the tab, and the reconcile hands the keyboard to it.
  public func focusGroup(_ id: TabGroup.ID) {
    store.focusGroup(id)
    reconcileSessions(takingFocus: true)
  }

  public func focusNextGroup() { focusAdjacentGroup(.after) }
  public func focusPreviousGroup() { focusAdjacentGroup(.before) }

  /// Wraps at either end, the way `activateAdjacentTab` walks a strip.
  private func focusAdjacentGroup(_ direction: TerminalTab.Placement) {
    guard
      let worktree = worktreeInView?.id,
      let current = workspace.focusedGroup(in: worktree),
      let next = workspace.groups(in: worktree).neighbour(of: current.id, direction)
    else { return }
    focusGroup(next.id)
  }

  /// Move Tab to New Group: the tab in front of the user gets a column of
  /// its own, to the right of the column it was in.
  public func moveActiveTabToNewGroup() {
    guard let group = focusedGroup, let tab = workspace.activeTab(in: group) else { return }
    moveTab(tab.id, .after, toNewGroupOf: group.id)
  }

  /// A tab dropped on the band down a column's edge, or the menu item above.
  /// `false` when nothing moved, so the drag springs back.
  @discardableResult
  public func moveTab(
    _ id: TerminalTab.ID, _ placement: TerminalTab.Placement, toNewGroupOf group: TabGroup.ID
  ) -> Bool {
    guard store.moveTabToNewGroup(id, placement, of: group) != nil else { return false }
    reconcileSessions(takingFocus: true)
    return true
  }

  /// A tab dropped on a column's strip clear of its tabs: it lands last
  /// there. A drop on a tab goes through `moveTab(_:_:_:)` instead.
  @discardableResult
  func moveTab(_ id: TerminalTab.ID, toEndOf group: TabGroup.ID) -> Bool {
    guard store.moveTab(id, toEndOf: group) else { return false }
    reconcileSessions(takingFocus: true)
    return true
  }

  /// Written back as the divider between two columns is dragged.
  public func setGroupWeights(_ weights: [Double], in worktree: Worktree.ID) {
    store.setGroupWeights(weights, in: worktree)
  }
}
