import MultishellCore

extension AppModel {
  /// A click on a tab of either kind.
  public func activateTab(_ id: WorkspaceTab.ID) {
    store.activateTab(id)
    reconcileSessions(takingFocus: true)
  }

  /// A pane of the selected worktree brought on screen with the keyboard, from
  /// its sidebar row. The reconcile hands the keyboard to the pane just focused.
  public func show(pane id: TerminalSession.ID) {
    guard let tab = workspace.tab(owning: id), isWorktreeInView(of: tab) else { return }
    store.focusSession(id)
    reconcileSessions(takingFocus: true)
  }

  /// A pane of any worktree brought on screen with the keyboard, its worktree
  /// selected; a missing directory alerts and leaves a cover such as the board up.
  func reveal(pane id: TerminalSession.ID) {
    guard let tab = workspace.tab(owning: id), let worktree = workspace.worktree(tab.worktreeID)
    else { return }
    select(worktree, openingFirstTab: .onSelect) { store.focusSession(id) }
  }

  public func activateNextTab() { activateAdjacentTab(.next) }
  public func activatePreviousTab() { activateAdjacentTab(.previous) }

  /// The tab one place along the strip, of either kind, wrapping at either end.
  private func activateAdjacentTab(_ direction: CycleDirection) {
    guard let current = workspaceTabInView,
      let next = workspace.neighbour(ofTab: current.id, direction)
    else { return }
    activateTab(next.id)
  }
}
