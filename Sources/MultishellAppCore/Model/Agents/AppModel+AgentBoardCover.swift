import MultishellCore

extension AppModel {
  public var showsAgentBoard: Bool { detailCover == .agentBoard }

  /// The board fills the detail area, the selection left alone so its shells
  /// stay live. The sweep makes the first frame honest; see `watchedPIDs`.
  public func showAgentBoard() {
    detailCover = .agentBoard
    sweepGonePIDs()
    updatePIDWatch()
  }

  /// `uncoverDetail`, where it is the board that covers the panes.
  func hideAgentBoard() {
    guard showsAgentBoard else { return }
    uncoverDetail()
  }

  /// The menu item and its keystroke, which go back to the worktree the
  /// second time rather than doing nothing.
  public func toggleAgentBoard() {
    if showsAgentBoard { hideAgentBoard() } else { showAgentBoard() }
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
  public func show(_ card: AgentBoardCard) {
    guard let tab = workspace.tab(card.tabID), let worktree = workspace.worktree(card.worktreeID)
    else { return }
    // The board is left by `select`, and only once it agrees to go: a
    // missing directory raises an alert and stays put.
    guard select(worktree) else { return }
    show(pane: card.id, in: tab)
  }
}
