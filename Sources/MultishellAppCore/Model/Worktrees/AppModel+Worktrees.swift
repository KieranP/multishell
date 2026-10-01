import Foundation
import MultishellCore
import MultishellGitKit

extension AppModel {
  /// The worktree in view when a shell may start in it. `nil` otherwise,
  /// the missing-directory alert already raised.
  func requireWorktreeForShell() -> Worktree? {
    worktreeInView.flatMap { requireShellReady($0) ? $0 : nil }
  }

  /// Whether a shell may start in `worktree`: no create or remove running or
  /// failed there, and its directory present. Every way of starting one asks.
  func requireShellReady(_ worktree: Worktree) -> Bool {
    !isBusy(worktree.id) && requireDirectory(of: worktree)
  }

  /// A worktree with no tabs gets one unless `TabOpening` says otherwise, and
  /// this is where the shared-hooks question is asked, a create being asked apart.
  @discardableResult
  public func select(_ worktree: Worktree, openingFirstTab: TabOpening = .onSelect) -> Bool {
    // A row git no longer lists is refused by the store, so ask first: the
    // board closing and a tab opening are not things to do for nothing.
    guard workspace.worktree(worktree.id) != nil, requireDirectory(of: worktree) else {
      return false
    }
    // Before anything else, `isPaneInView` having to agree that panes fill the
    // detail area. The seen-clearing is left to the reconcile at the end.
    hideAgentBoard(markingInViewSeen: false)
    store.selectWorktree(worktree.id)
    warmWorktrees.insert(worktree.id)
    if openingFirstTab != .onCreate { askAboutSharedSettingsIfNeeded(for: worktree.projectID) }
    if wantsFirstTab(in: worktree, on: openingFirstTab) {
      addDefaultTab(in: worktree, on: openingFirstTab)
    }
    reconcileSessions(takingFocus: true)
    return true
  }

  /// A create or remove is running there, or has failed and not been
  /// dismissed. Nothing starts a shell until then.
  public func isBusy(_ id: Worktree.ID) -> Bool {
    worktreeOperations.isBusy(id)
  }

  /// A checkout, a file list or a hook of a create or a removal is writing
  /// there, so git reads a half-made tree; see worktrees.md.
  func isBeingWritten(_ id: Worktree.ID) -> Bool {
    hasStageWriting(id) || workspace.worktree(id)?.isInitializing == true
  }

  /// The same for a worktree in hand, which the poll asks of every row: the
  /// lookup by id scans the list, and a round asking it per row went quadratic.
  func isBeingWritten(_ worktree: Worktree) -> Bool {
    hasStageWriting(worktree.id) || worktree.isInitializing
  }

  private func hasStageWriting(_ id: Worktree.ID) -> Bool {
    pathClaims.isClaimed(id) || worktreeOperations.isRunning(id)
  }

  /// The pane's Dismiss after a failed stage. A dismissed create stage
  /// hands over the way a finished one does: the first tab opens.
  public func dismissOperationFailure(of worktree: Worktree) {
    guard let operation = worktreeOperations.dismiss(worktree.id) else { return }
    if operation.step.isCreation { openHeldBackTab(of: worktree) }
  }

  /// The pane's Cancel: ends the stage running there, a hook by signal and a
  /// file list at its next path. What follows depends on the stage.
  public func cancelStage(of worktree: Worktree) {
    stageHandles.stopStage(of: worktree.id)
  }

  public func setHookTimeoutSeconds(_ seconds: Int) {
    store.setHookTimeoutSeconds(seconds)
  }

  public func setWorktreeDefaults(_ defaults: WorktreeSettings) {
    store.setWorktreeDefaults(defaults)
  }

  /// Checked before anything that starts a shell, a missing directory being
  /// refused. Named for the demand, since it raises the alert itself.
  func requireDirectory(of worktree: Worktree) -> Bool {
    switch directoryProbe.probe(worktree.path.path) {
    case .present:
      noteDirectoryPresent(of: worktree.id)
      return true
    case .missing: presentedError = .worktreeDirectoryMissing(worktree.path.path)
    case .unanswered: presentedError = .worktreeDirectoryUnanswered(worktree.path.path)
    }
    return false
  }

  /// The one place per-worktree runtime state is dropped, fed with what the
  /// store discarded. Paths are ids, so a worktree re-made there starts clean.
  func forgetWorktrees(_ ids: [Worktree.ID]) {
    guard !ids.isEmpty else { return }
    let gone = Set(ids)
    setIfChanged(\.statuses, statuses.filter { !gone.contains($0.key) })
    forgetMergeStates(ofWorktrees: gone)
    setIfChanged(\.lastCommitDates, lastCommitDates.filter { !gone.contains($0.key) })
    resolvedWorktreeComponents = resolvedWorktreeComponents.filter { !gone.contains($0.key) }
    worktreesResolvedWhileMissing.subtract(gone)
    removalStatusReads = removalStatusReads.filter { !gone.contains($0.key) }
    // Their sessions went with them, so a worktree re-made at the path starts cold.
    warmWorktrees.subtract(gone)
    statusReads.forget(gone)
    coordinator?.forgetStatusReads(of: ids)
    for id in ids {
      // A stage still running has no pane left to Cancel from, so it is ended
      // as that Cancel would end it; its task lets go of these as it returns.
      stageHandles.stopStage(of: id)
      worktreeOperations.clear(id)
      pendingStatusRefreshes[id]?.cancel()
      pendingStatusRefreshes[id] = nil
    }
    if let renaming = renamingWorktreeID, gone.contains(renaming) { renamingWorktreeID = nil }
    if let pending = pendingWorktreeRemoval, gone.contains(pending.worktree.id) {
      pendingWorktreeRemoval = nil
    }
    if let latest = latestRemovalRequest, gone.contains(latest) { latestRemovalRequest = nil }
  }
}
