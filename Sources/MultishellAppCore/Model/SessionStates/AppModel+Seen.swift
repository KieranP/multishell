import MultishellCore

extension AppModel {
  /// Seen: the pane with the keyboard, and its window looked at. A split's other
  /// pane is in view but not looked at, so its Done waits for its focus.
  func isSeen(_ id: TerminalSession.ID) -> Bool {
    isFocusedPane(id) && worktreeIDWithTabsDrawn != nil && isWorkspaceWindowLookedAt
  }

  /// The focused pane and the selected worktree are seen; every pane in view
  /// loses its banner. Guarded on its tabs drawn and looked at, as `isSeen` is.
  func markInViewSeen() {
    guard isWorkspaceWindowLookedAt, let worktree = worktreeIDWithTabsDrawn else { return }
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
