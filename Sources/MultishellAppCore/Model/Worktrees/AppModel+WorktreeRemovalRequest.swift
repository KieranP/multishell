import Foundation
import MultishellCore

extension AppModel {
  /// Asks first unless the settings have settled both questions; nothing while an
  /// operation runs there. The task ends once the dialog is up or the removal is over.
  @discardableResult
  public func requestWorktreeRemoval(of worktree: Worktree) -> Task<Void, Never>? {
    guard worktree.isRemovable, !isBusy(worktree.id) else { return nil }
    if case .remove(let deletesBranch) = removalDecision(for: worktree) {
      return Task { await removeWorktree(worktree, deletesBranch: deletesBranch) }
    }
    latestRemovalRequestID = worktree.id
    guard removalsAwaitingStatus.insert(worktree.id).inserted else { return nil }
    // Any row's status may be as old as the pace allows, and the dialog,
    // built once, warns of the changed files that status counts.
    return Task {
      let hasUnreadChanges = await !readsFreshStatusInTime(of: worktree.id)
      removalsAwaitingStatus.remove(worktree.id)
      let isLatest = latestRemovalRequestID == worktree.id
      if isLatest { latestRemovalRequestID = nil }
      // A late read must not swap the dialog up, or a newer click's, for its own.
      guard isLatest, pendingWorktreeRemoval == nil, let current = workspace.worktree(worktree.id),
        !isBusy(current.id)
      else { return }
      switch removalDecision(for: current, hasUnreadChanges: hasUnreadChanges) {
      case .ask(let pending): pendingWorktreeRemoval = pending
      case .remove(let deletesBranch):
        await removeWorktree(current, deletesBranch: deletesBranch)
      }
    }
  }

  /// Whether a read begun after the click landed within the wait. An earlier
  /// removal's read still running is waited out first rather than stacked on.
  private func readsFreshStatusInTime(of id: Worktree.ID) async -> Bool {
    let deadline = ContinuousClock.now + removalStatusWait
    if let earlier = removalStatusReads[id], await earlier.value(within: removalStatusWait) == nil {
      return false
    }
    return await startRemovalStatusRead(of: id).value(within: deadline - .now) == true
  }

  private func startRemovalStatusRead(of id: Worktree.ID) -> Task<Bool, Never> {
    let statusRead = Task { await refreshStatus(of: id, forced: true) }
    removalStatusReads[id] = statusRead
    // A worktree re-made at the path may have a read of its own by then.
    Task {
      _ = await statusRead.value
      if removalStatusReads[id] == statusRead { removalStatusReads[id] = nil }
    }
    return statusRead
  }

  private func removalDecision(
    for worktree: Worktree, hasUnreadChanges: Bool = false
  ) -> PendingWorktreeRemoval.Decision {
    PendingWorktreeRemoval.decide(
      worktree, customName: customName(of: worktree),
      confirms: workspace.confirmsWorktreeRemoval,
      alwaysDeletesBranch: workspace.deletesBranchWithWorktree,
      trashes: workspace.trashesRemovedWorktrees, mergeState: mergeState(of: worktree),
      hasUnreadChanges: hasUnreadChanges)
  }

  /// The dialog's answer: the index of the button chosen, `nil` for Cancel.
  /// The task is the removal, when one was chosen.
  @discardableResult
  public func answerWorktreeRemoval(
    _ pending: PendingWorktreeRemoval, choice: Int?
  ) -> Task<Void, Never>? {
    pendingWorktreeRemoval = nil
    guard let choice, pending.choices.indices.contains(choice) else { return nil }
    let deletesBranch = pending.choices[choice].deletesBranch
    return Task { await removeAsConfirmed(pending, deletesBranch: deletesBranch) }
  }

  /// Trashing or deleting as the dialog's message said, even if the setting
  /// changed while it was up.
  func removeAsConfirmed(
    _ pending: PendingWorktreeRemoval, deletesBranch: Bool
  ) async {
    await removeWorktree(pending.worktree, deletesBranch: deletesBranch, trashes: pending.trashes)
  }

  /// What the confirmation should warn about, beyond the removal itself.
  public func worktreeRemovalWarning(for pending: PendingWorktreeRemoval) -> String? {
    PendingWorktreeRemoval.warning(
      changedFiles: statuses[pending.worktree.id]?.changedFiles ?? 0,
      hasUnreadChanges: pending.hasUnreadChanges,
      liveTerminals: liveTerminalCount(in: pending.worktree.id),
      trashes: pending.trashes)
  }
}
