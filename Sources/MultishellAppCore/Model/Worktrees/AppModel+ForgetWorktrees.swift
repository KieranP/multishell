import MultishellCore

extension AppModel {
  /// The one place per-worktree runtime state is dropped, fed with what the
  /// store discarded. Paths are ids, so a worktree re-made there starts clean.
  func forgetWorktrees(_ ids: [Worktree.ID]) {
    guard !ids.isEmpty else { return }
    let gone = Set(ids)
    setIfChanged(\.statuses, statuses.filter { !gone.contains($0.key) })
    forgetMergeStates(ofWorktrees: gone)
    setIfChanged(\.lastCommitDates, lastCommitDates.filter { !gone.contains($0.key) })
    pathResolutions.forget(gone)
    removalRequests.forget(gone)
    // Their sessions went with them, so a worktree re-made at the path starts cold.
    warmWorktrees.subtract(gone)
    statusReadLog.forget(gone)
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
  }
}
