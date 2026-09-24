import Foundation
import MultishellCore

extension AppModel {
  /// Brings the host in line with the store. Every action that changes which
  /// terminals exist ends here; only a user's own action takes the keyboard.
  func reconcileSessions(takingFocus: Bool) {
    reconcile()
    guard takingFocus else { return }
    // The keyboard is a pane's now, whatever field held it.
    findFieldPane = nil
    registry.focusActiveSession()
    markFocusedPaneSeen()
  }

  /// For a control that is leaving, such as the sidebar filter on Escape: the
  /// keyboard would otherwise fall to the window and type into nothing.
  public func focusActivePane() {
    guard !showsAgentBoard else { return }
    registry.focusActiveSession()
  }

  /// Surfaces brought in line with the workspace, the keyboard left alone: a
  /// poll reaches this too, and focusing would take it off a field being typed in.
  private func reconcile() {
    // A copy still here after handing over has no socket of its own, and the
    // config a shell's engine writes would outlive its quit; state-and-store.md.
    let warm = yieldingToRunningInstance ? [] : warmWorktrees
    let failures = registry.reconcile(
      shouldBeLive: { warm.contains($0.worktreeID) }, prepare: { prepared($0) })
    for (index, failure) in failures.enumerated() {
      // One alert slot: four sessions failing at once would otherwise leave
      // one message about the last of them and nothing about the rest.
      if index == 0 {
        report(failure.error)
      } else {
        platform.log("a session could not be opened: \(failure.error)")
      }
      store.closeSession(failure.sessionID)
    }
    pruneStates()
    prunePendingClose()
    pruneFind()
  }

  /// The focused pane and the selected worktree are seen; every pane in view
  /// loses its banner. Guarded on the board and frontmost, as `hasBeenSeen` is.
  func markFocusedPaneSeen() {
    guard platform.isActive, !showsAgentBoard, let worktree = workspace.selectedWorktreeID
    else { return }
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

  public func report(_ error: any Error) {
    presentedError = PresentedError(error)
  }
}
