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

  public func activateNextTab() { activateAdjacentTab(.next) }
  public func activatePreviousTab() { activateAdjacentTab(.previous) }

  /// The tab one place along the strip, wrapping at either end.
  private func activateAdjacentTab(_ direction: CycleDirection) {
    guard
      let current = tabInView,
      let next = direction == .next
        ? workspace.tab(after: current.id) : workspace.tab(before: current.id)
    else { return }
    activate(next)
  }
}
