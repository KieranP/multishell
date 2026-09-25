import MultishellCore

/// A worktree's terminal area is one or more groups of tabs. All layout, so
/// none of it asks whether a shell could start.
extension AppModel {
  /// The group the keystrokes go to, which is what the menu items and the
  /// tab-strip chrome are drawn from.
  var focusedGroup: TabGroup? {
    worktreeInView.flatMap { workspace.focusedGroup(in: $0.id) }
  }

  /// A click anywhere in a group's strip. The pane keeps whatever focus it
  /// had inside the tab, and the reconcile hands the keyboard to it.
  public func focusGroup(_ id: TabGroup.ID) {
    store.focusGroup(id)
    reconcileSessions(takingFocus: true)
  }

  public func focusNextGroup() { focusAdjacentGroup(.next) }
  public func focusPreviousGroup() { focusAdjacentGroup(.previous) }

  /// Wraps at either end, the way `activateAdjacentTab` walks a strip.
  private func focusAdjacentGroup(_ direction: CycleDirection) {
    guard
      let worktree = worktreeInView?.id,
      let current = workspace.focusedGroup(in: worktree),
      let next = workspace.groups(in: worktree).neighbour(of: current.id, direction)
    else { return }
    focusGroup(next.id)
  }

  /// Written back as the divider between two groups is dragged.
  public func setGroupWeights(_ weights: [Double], in worktree: Worktree.ID) {
    store.setGroupWeights(weights, in: worktree)
  }
}
