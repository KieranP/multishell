import MultishellCore

extension AppModel {
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
    if operation.stage.isSetup { openHeldBackTab(of: worktree) }
  }

  /// The pane's Cancel: ends the stage running there, a hook by signal and a
  /// file list at its next path. What follows depends on the stage.
  public func cancelStage(of worktree: Worktree) {
    stageHandles.stopStage(of: worktree.id)
  }
}
