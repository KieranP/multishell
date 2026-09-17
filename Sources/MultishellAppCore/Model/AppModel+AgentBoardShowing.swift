import MultishellCore

extension AppModel {
  /// The board fills the detail area, the selection left alone so its shells
  /// stay live. The sweep makes the first frame honest; see `watchedPIDs`.
  public func showAgentBoard() {
    showsAgentBoard = true
    sweepGonePIDs()
    updatePIDWatch()
  }

  /// The panes are back in front of the user, and the focused one's Done seen.
  public func hideAgentBoard() {
    guard showsAgentBoard else { return }
    leaveAgentBoard()
    markFocusedPaneSeen()
  }

  /// The menu item and its keystroke, which go back to the worktree the
  /// second time rather than doing nothing.
  public func toggleAgentBoard() {
    if showsAgentBoard { hideAgentBoard() } else { showAgentBoard() }
  }

  /// Puts the panes back without the seen-clearing, for callers doing their
  /// own. The watch is told, what it polls depending on the board.
  func leaveAgentBoard() {
    guard showsAgentBoard else { return }
    showsAgentBoard = false
    updatePIDWatch()
  }

  public func setShowsAllTerminals(_ shows: Bool) {
    guard shows != showsAllTerminals else { return }
    showsAllTerminals = shows
    // The badge counts what the Waiting column shows, and the filter just
    // changed what that is.
    updateDockBadge()
  }

  /// A click on a card: turn to its pane and leave the board. The card stays,
  /// moving to Idle if what was shown was a Done.
  public func open(_ card: AgentBoardCard) {
    guard let tab = workspace.tab(card.tabID), let worktree = workspace.worktree(card.worktreeID)
    else { return }
    // The board is left by `select`, and only once it agrees to go: a
    // missing directory raises an alert and stays put.
    guard select(worktree) else { return }
    show(pane: card.id, in: tab)
  }

  /// The count on the app's icon: what the Waiting column shows. Pushed, the
  /// port being a plain protocol with no way to watch a value.
  func updateDockBadge() {
    let waiting = agentLaneCounts[.waiting] ?? 0
    guard waiting != badgedWaitingCount else { return }
    badgedWaitingCount = waiting
    platform.setBadgeCount(waiting > 0 ? waiting : nil)
  }
}
