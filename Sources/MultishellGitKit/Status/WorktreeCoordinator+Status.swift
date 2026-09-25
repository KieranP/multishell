import MultishellCore

/// Many worktrees' statuses read side by side, and what those reads remember.
extension WorktreeCoordinator {
  /// Statuses for many worktrees at once, each with how long git took, one
  /// that could not be read simply absent. At most `maxConcurrentReads` run together.
  public func readStatuses(
    of worktrees: [Worktree], counting indicator: GitStatusIndicator = .default
  ) async -> [Worktree.ID: StatusReading] {
    let readings = await worktrees.filter { !$0.isBare }.concurrentMap(
      width: SharedGitReads.maxConcurrentReads
    ) { worktree in
      let started = ContinuousClock.now
      let status = try? await git.status(of: worktree, counting: indicator)
      return (
        worktree.id, status.map { StatusReading(status: $0, took: started.duration(to: .now)) }
      )
    }
    return Dictionary(
      readings.compactMap { id, reading in reading.map { (id, $0) } },
      uniquingKeysWith: { _, last in last })
  }

  /// Drops what the status reads remember about worktrees that have gone.
  public func forgetStatusReads(of ids: [Worktree.ID]) {
    git.shared.untrackedMemo.forget(directories: ids)
  }
}
