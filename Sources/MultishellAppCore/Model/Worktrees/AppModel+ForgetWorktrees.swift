import MultishellCore
import MultishellGitKit

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
    newWorktreeFirstTabs = newWorktreeFirstTabs.filter { !gone.contains($0.key) }
    statusReadLog.forget(gone)
    coordinator?.forgetStatusReads(of: ids)
    for id in ids {
      // A stage still running has no pane left to Cancel from, so it is ended
      // as that Cancel would end it; its task lets go of these as it returns.
      stageHandles.stopStage(of: id)
      worktreeOperations.clear(id)
      pendingStatusRefreshes[id]?.cancel()
      pendingStatusRefreshes[id] = nil
      ignoreVerdicts[id] = nil
      filesPanelStates[id] = nil
      fileTreeCache[id] = nil
      pendingFileTreeListings[id]?.task.cancel()
      pendingFileTreeListings[id] = nil
      pendingTrackedFilesReads[id]?.cancel()
      pendingTrackedFilesReads[id] = nil
      pendingIgnoredEntriesReads[id]?.cancel()
      pendingIgnoredEntriesReads[id] = nil
    }
    ignoredEntriesAskedAgain.subtract(gone)
    setIfChanged(\.trackedFiles, trackedFiles.filter { !gone.contains($0.key) })
    fileTreeListings = fileTreeListings.filter { !gone.contains($0.key) }
    setIfChanged(\.submoduleReadings, submoduleReadings.filter { !gone.contains($0.key) })
    setIfChanged(\.ignoredEntries, ignoredEntries.filter { !gone.contains($0.key) })
    setIfChanged(\.ignoredFolderEntries, ignoredFolderEntries.filter { !gone.contains($0.key) })
    if let renaming = renamingWorktreeID, gone.contains(renaming) { renamingWorktreeID = nil }
    if let pending = pendingWorktreeRemoval, gone.contains(pending.worktree.id) {
      pendingWorktreeRemoval = nil
    }
  }
}
