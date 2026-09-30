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
    tabInView?.focusedSessionID == id
  }

  /// The focused pane and the selected worktree are seen; every pane in view
  /// loses its banner. Guarded on the board and frontmost, as `isSeen` is.
  func markInViewSeen() {
    guard platform.isActive, let worktree = worktreeIDInView else { return }
    let focused = tabInView.map { [$0.focusedSessionID] } ?? []
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
