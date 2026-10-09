import Foundation
import MultishellCore
import MultishellProcess

extension WorktreeCoordinator {
  /// Pre-delete hook, the directory to `trash`, the record forgotten,
  /// post-delete hook, the branch last. See worktrees.md and hooks.md.
  public func remove(
    _ worktree: Worktree,
    in project: Project,
    trash: @Sendable (URL) async throws -> Void,
    deletesBranch: Bool = false,
    shellPath: String? = nil,
    timeout: Duration? = nil,
    stopper: ProcessStopper? = nil,
    onStep: (@Sendable (WorktreeRemovalStep) -> Void)? = nil,
  ) async throws {
    // The main worktree is the repository, `.git` and all, and the trash
    // step would bin it. Nothing below this guard checks.
    guard worktree.isRemovable else {
      throw WorktreeNotRemovable(path: worktree.path)
    }
    let path = worktree.path
    let directoryExists = await runOnDispatch { FileManager.default.fileExists(atPath: path.path) }
    // Whatever took a stale record's path since is not ours: not trashed,
    // and no hook runs, each being handed that path; see worktrees.md.
    if directoryExists, try await !git.isCheckout(of: worktree, in: project) {
      onStep?(.removingWorktree)
      try await git.removeStaleRecord(worktree, in: project)
    } else {
      try await removeCheckout(
        worktree,
        directoryExists: directoryExists,
        in: project,
        trash: trash,
        shellPath: shellPath,
        timeout: timeout,
        stopper: stopper,
        onStep: onStep,
      )
    }
    if deletesBranch, let branch = worktree.branch {
      onStep?(.deletingBranch)
      try await deleteBranch(branch, in: project)
    }
  }

  private func removeCheckout(
    _ worktree: Worktree,
    directoryExists: Bool,
    in project: Project,
    trash: @Sendable (URL) async throws -> Void,
    shellPath: String?,
    timeout: Duration?,
    stopper: ProcessStopper?,
    onStep: (@Sendable (WorktreeRemovalStep) -> Void)?,
  ) async throws {
    let path = worktree.path
    let branchOrHead = worktree.branch ?? worktree.head
    try await WorktreeHooks.run(
      .preDelete,
      for: project,
      worktreePath: path,
      branch: branchOrHead,
      shellPath: shellPath,
      timeout: timeout,
      stopper: stopper,
      onWillRun: { onStep?(.preDeleteHook) },
    )
    onStep?(.removingWorktree)
    if directoryExists {
      do {
        try await trash(path)
      } catch {
        throw TrashFailure(path: path, underlying: error)
      }
      // `removeRecord` would unlink a directory still here; only the Trash may take it.
      guard await !runOnDispatch({ FileManager.default.fileExists(atPath: path.path) }) else {
        throw TrashFailure(path: path, underlying: TrashTookNothing())
      }
    }
    try await git.removeRecord(of: worktree, in: project)
    try await WorktreeHooks.run(
      .postDelete,
      for: project,
      worktreePath: path,
      branch: branchOrHead,
      shellPath: shellPath,
      timeout: timeout,
      stopper: stopper,
      onWillRun: { onStep?(.postDeleteHook) },
    )
  }
}
