import MultishellCore

extension AppModel {
  public var showsAgentBoard: Bool { detailCover == .agentBoard }

  /// The board fills the detail area, the selection left alone so its shells
  /// stay live. The sweep makes the first frame honest; see `watchedPIDs`.
  public func showAgentBoard() {
    let polledBefore = polledRowIDs()
    detailCover = .agentBoard
    sweepGonePIDs()
    updatePIDWatch()
    // Rows only the board shows went unread while it was closed, as a
    // collapsed project's do.
    let revealed = polledRowIDs().subtracting(polledBefore)
    guard !revealed.isEmpty else { return }
    Task { await refreshStatuses { revealed.contains($0.id) } }
  }

  /// `uncoverDetailAndReadItsTabs`, where it is the board that covers the panes.
  func hideAgentBoard() {
    guard showsAgentBoard else { return }
    uncoverDetailAndReadItsTabs()
  }

  /// The menu item and its keystroke, which go back to the worktree the
  /// second time rather than doing nothing.
  public func toggleAgentBoard() {
    if showsAgentBoard { hideAgentBoard() } else { showAgentBoard() }
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
