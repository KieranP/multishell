import MultishellCore

/// What a worktree's actions menu offers about its base.
public enum BaseUpdateMenu: Equatable, Sendable {
  /// Stopped partway: Abort, and Send Conflicts To where any path is unmerged.
  case unfinished(UpdateMethod, sendTargets: ConflictSendTargets?, isRunning: Bool)
  /// Merge from and Rebase onto `base`, greyed while one runs.
  case update(base: String, isRunning: Bool)
}
