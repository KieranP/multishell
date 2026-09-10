import MultishellCore

// MARK: - Showing the board, and leaving it

extension AppModel {
  /// The board fills the detail area in place of the selected worktree's
  /// terminals. The selection itself is left alone, so its shells stay live
  /// and the worktree a card opens is still warm.
  ///
  /// Nothing on screen is a pane from here, so a Done that arrives while the
  /// board is up is one the user has not seen; see `isShown`. The sweep is
  /// what makes the first frame honest: while the board is down nothing
  /// watches for an agent quitting, so a card could otherwise open stale.
  /// See `watchedPIDs`.
  public func showAgentBoard() {
    showsAgentBoard = true
    sweepGonePIDs()
    updatePIDWatch()
  }

  /// The panes are back in front of the user, and a Done among them has now
  /// been seen. `markShownTabSeen` goes through `mutateStates`, which is
  /// what moves the badge if that changed anything.
  public func hideAgentBoard() {
    guard showsAgentBoard else { return }
    leaveAgentBoard()
    markShownTabSeen()
  }

  /// The menu item and its keystroke, which go back to the worktree the
  /// second time rather than doing nothing.
  public func toggleAgentBoard() {
    if showsAgentBoard { hideAgentBoard() } else { showAgentBoard() }
  }

  /// Puts the panes back in front without the seen-clearing, for the callers
  /// that go on to do their own; see `select` and `open`. The watch is told,
  /// because what it has to poll depends on the board being up.
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

  /// A click on a card: turn to the pane it stands for and leave the board.
  /// The card does not go anywhere — it moves to Idle if what was just shown
  /// was a Done, which is the same rule the sidebar dot has always followed.
  public func open(_ card: AgentBoardCard) {
    guard let tab = workspace.tab(card.tabID), let worktree = workspace.worktree(card.worktreeID)
    else { return }
    // The board is left by `select`, and only once it has agreed to go: a
    // worktree whose directory has gone raises an alert and stays put, and
    // closing the board under that alert would answer a click that failed.
    guard select(worktree) else { return }
    store.activateTab(tab.id)
    store.focusSession(card.id)
    //  hands the keyboard to the active tab's focused pane, which the
    // line above just made this one; nothing further is needed to land in it.
    sync()
  }

  /// The count on the app's icon: exactly what the Waiting column shows,
  /// failures included, so the badge and the board can never disagree.
  /// Pushed from wherever the states change rather than observed, the port
  /// being a plain protocol with no way to watch a value.
  func updateDockBadge() {
    let waiting = agentLaneCounts[.waiting] ?? 0
    guard waiting != badgedWaitingCount else { return }
    badgedWaitingCount = waiting
    platform.setBadgeCount(waiting > 0 ? waiting : nil)
  }
}
