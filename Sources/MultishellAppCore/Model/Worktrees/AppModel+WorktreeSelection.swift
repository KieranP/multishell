import MultishellCore

extension AppModel {
  /// The user turning to a worktree; see `select(_:openingFirstTab:turning:)`.
  @discardableResult
  public func select(_ worktree: Worktree) -> Bool {
    select(worktree, openingFirstTab: .onSelect)
  }

  /// A worktree with no tabs gets one unless `TabOpeningReason` says otherwise. `turn`
  /// runs only once nothing can refuse, after that tab and before the focus.
  @discardableResult
  func select(
    _ worktree: Worktree,
    openingFirstTab: TabOpeningReason,
    turning turn: () -> Void = {},
  ) -> Bool {
    // A row git no longer lists is refused by the store, so ask first: a
    // cover closing and a tab opening are not things to do for nothing.
    guard workspace.worktree(worktree.id) != nil, requireDirectory(of: worktree) else {
      return false
    }
    // Before anything else, `isPaneInView` having to agree that panes fill the
    // detail area. The seen-clearing is left to the reconcile at the end.
    uncoverDetail(markingInViewSeen: false)
    store.selectWorktree(worktree.id)
    noteRecentWorktree(worktree.id)
    warmWorktrees.insert(worktree.id)
    // A create asks the shared-hooks question apart.
    if openingFirstTab != .onCreate { askAboutSharedSettingsIfNeeded(for: worktree.projectID) }
    if wantsFirstTab(in: worktree, for: openingFirstTab) {
      addDefaultTab(in: worktree, for: openingFirstTab)
    }
    // The caller's tab or pane, turned to before the focus marks the one it lands in seen.
    turn()
    reconcileSessions(takingFocus: true)
    return true
  }
}
