import Foundation
import MultishellCore

/// Many worktrees' statuses read side by side, and what those reads remember.
extension WorktreeCoordinator {
  /// Statuses for many worktrees at once, each with how long git took, one unread absent; at
  /// most `maximumConcurrentReads` together. A branch never pushed counts ahead of `bases`.
  public func readStatuses(
    of worktrees: [Worktree],
    counting indicator: GitStatusIndicator = .default,
    diffAlgorithm: DiffAlgorithm = .default,
    bases: [Project.ID: DefaultBranch] = [:],
  ) async -> [Worktree.ID: StatusReading] {
    let readings = await worktrees.filter { !$0.isBare }.mapConcurrentlyUnordered(
      width: SharedReadState.maximumConcurrentReads
    ) { worktree in
      let started = ContinuousClock.now
      let status = try? await git.status(
        of: worktree,
        counting: indicator,
        diffAlgorithm: diffAlgorithm,
        against: bases[worktree.projectID],
      )
      return (
        worktree.id,
        status.map { StatusReading(status: $0, duration: started.duration(to: .now)) },
      )
    }
    return Dictionary(
      readings.compactMap { id, reading in reading.map { (id, $0) } },
      uniquingKeysWith: { _, last in last },
    )
  }

  /// Drops what the status reads remember about worktrees that have gone,
  /// by path, which is what a worktree's id is.
  public func forgetStatusReads(of ids: [Worktree.ID]) {
    git.readState.untrackedMemo.forget(
      directories: ids.map { URL(fileURLWithPath: $0, isDirectory: true) }
    )
  }
}
