import MultishellCore

extension AppModel {
  /// Seen: the pane with the keyboard, and the app in front. A split's other
  /// pane is in view but not looked at, so its Done waits for its focus.
  func isSeen(_ id: TerminalSession.ID) -> Bool {
    isFocused(id) && platform.isActive
  }

  /// The pane the keyboard goes to: the selected worktree's active tab's
  /// focused pane, with the board hidden. What clears a Done.
  private func isFocused(_ id: TerminalSession.ID) -> Bool {
    guard let worktree = worktreeIDInView else { return false }
    return workspace.activeTab(in: worktree)?.focusedSessionID == id
  }

  /// The pane is on screen: its worktree selected and its tab shown, asked
  /// of every group. What holds a banner back, saying nothing about focus.
  func isPaneInView(_ id: TerminalSession.ID) -> Bool {
    // The board fills the detail area, so no pane is on screen behind it,
    // and a card would reach Idle having never passed through Done.
    guard let worktree = worktreeIDInView else { return false }
    return workspace.shownTabs(in: worktree).contains { $0.root.contains(id) }
  }

  /// The focused pane and the selected worktree are seen; every pane in view
  /// loses its banner. Guarded on the board and frontmost, as `isSeen` is.
  func markInViewSeen() {
    guard platform.isActive, let worktree = worktreeIDInView else { return }
    let focused = workspace.activeTab(in: worktree).map { [$0.focusedSessionID] } ?? []
    if sessionStates.hasAnythingToSee(sessions: focused, worktree: worktree) {
      mutateStates { $0.markSeen(sessions: focused, worktree: worktree) }
    }
    guard !notifiedKeys.isEmpty else { return }
    for id in workspace.shownTabs(in: worktree).flatMap(\.sessionIDs) {
      withdrawNotification(about: .session(id))
    }
    withdrawNotification(about: .worktree(worktree))
  }
}
