import MultishellCore

/// Each worktree's path with its symlinks resolved, for placing a report that
/// names only a directory. Stale where a link is repointed or the path was away.
struct WorktreePathResolutions {
  var components: [Worktree.ID: [String]] = [:]
  /// Worktrees whose kept resolution was made while their directory was away.
  var madeWhileMissing: Set<Worktree.ID> = []
  /// Those being looked at again, one at a time each, so a hung mount holds a
  /// thread per worktree on it and no other worktree waits on it.
  var beingRechecked: Set<Worktree.ID> = []

  mutating func forget(_ gone: Set<Worktree.ID>) {
    components = components.filter { !gone.contains($0.key) }
    madeWhileMissing.subtract(gone)
  }
}
