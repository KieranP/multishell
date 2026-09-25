import MultishellCore

extension AppModel {
  /// Cmd+W closes the focused pane; the tab goes with its last pane.
  public func closeActivePane() {
    closeInShownTab { .pane($0.focusedSessionID) }
  }

  /// Cmd+Shift+W closes the whole tab, panes and all.
  public func closeActiveTab() {
    closeInShownTab { .tab($0.id) }
  }

  /// A middle click on a tab, closing it active or not. No key-window dance:
  /// the click landed here, so this window is the one being acted in.
  public func closeTab(_ id: TerminalTab.ID) {
    guard let tab = workspace.tab(id) else { return }
    requestClose(.tab(id), in: tab)
  }

  /// The confirmed half of a close that found a working agent.
  public func confirmPendingClose() {
    guard let pending = pendingClose else { return }
    pendingClose = nil
    perform(pending)
  }

  /// A close or a name field whose subject has gone has nothing left to ask.
  /// Run from the reconcile, so every path that takes one away is covered.
  func pruneTabPrompts() {
    switch pendingClose {
    case .pane(let id) where workspace.session(id) == nil: pendingClose = nil
    case .tab(let id) where workspace.tab(id) == nil: pendingClose = nil
    default: break
    }
    // A name field whose tab has gone, as a renamed worktree drops its own.
    if let renaming = renamingTabID, workspace.tab(renaming) == nil { renamingTabID = nil }
  }

  // The three entry points above meet here, the keystrokes through
  // `closeInShownTab`, which has to find the tab first.

  /// Both keystrokes. One issued in a settings window closes that window
  /// instead, and nothing happens with no tab on screen.
  private func closeInShownTab(_ closing: (TerminalTab) -> PendingClose) {
    guard platform.workspaceWindowIsKey else { return platform.closeKeyWindow() }
    guard let worktree = worktreeInView?.id, let tab = workspace.activeTab(in: worktree)
    else { return }
    requestClose(closing(tab), in: tab)
  }

  /// A close whose panes hold a working agent is asked about rather than
  /// done; `PendingClose` says which shells each form would end.
  private func requestClose(_ close: PendingClose, in tab: TerminalTab) {
    if close.sessionIDs(in: tab).contains(where: isAgentWorking(in:)) {
      pendingClose = close
      return
    }
    perform(close)
  }

  private func perform(_ close: PendingClose) {
    switch close {
    case .pane(let id): store.closeSession(id)
    case .tab(let id): store.closeTab(id)
    }
    reconcileSessions(takingFocus: true)
  }
}
