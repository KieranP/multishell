import MultishellCore

/// Removals waiting on a fresh status read before they ask, so the dialog can
/// warn of changes the last poll did not count.
struct WorktreeRemovalRequests {
  /// Worktrees whose removal is reading their status.
  var awaitingStatus: Set<Worktree.ID> = []
  /// Each removal's read until git answers, which outlives the removal's wait
  /// on a dead mount; a later removal waits on it rather than start another.
  var statusReads: [Worktree.ID: Task<Bool, Never>] = [:]
  /// How long a removal waits for that read before it asks anyway.
  var statusWait: Duration = .seconds(3)
  /// The removal asked last, the only one whose read may put up a dialog.
  var latestID: Worktree.ID?

  mutating func forget(_ gone: Set<Worktree.ID>) {
    statusReads = statusReads.filter { !gone.contains($0.key) }
    if let latestID, gone.contains(latestID) { self.latestID = nil }
  }
}
