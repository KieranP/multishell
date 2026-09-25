import Foundation
import MultishellCore
import MultishellProcess

extension WorktreeCoordinator {
  /// Pre-delete hook, the directory to `trash`, the record forgotten,
  /// post-delete hook, the branch last. See worktrees.md and hooks.md.
  public func remove(
    _ worktree: Worktree, deletingBranch: Bool = false, in project: Project,
    shellPath: String? = nil, trash: @Sendable (URL) async throws -> Void,
    timeout: Duration? = nil, stopper: ProcessStopper? = nil,
    onStep: (@Sendable (WorktreeRemovalStep) -> Void)? = nil
  ) async throws {
    // The main worktree is the repository, `.git` and all, and the trash
    // step would bin it. Nothing below this guard checks.
    guard worktree.isRemovable else {
      throw WorktreeNotRemovable(path: worktree.path)
    }
    let path = worktree.path
    let branch = worktree.branch ?? worktree.head
    let isThere = FileManager.default.fileExists(atPath: path.path)
    // Whatever took a stale record's path since is not ours: not trashed,
    // and no hook runs, each being handed that path; see worktrees.md.
    if isThere, try await !git.isCheckout(of: worktree, in: project) {
      onStep?(.removingWorktree)
      try await git.forgetStale(worktree, in: project)
    } else {
      try await WorktreeHooks.run(
        .preDelete, for: project, worktreePath: path, branch: branch, shellPath: shellPath,
        timeout: timeout, stopper: stopper, willRun: { onStep?(.preDeleteHook) })
      onStep?(.removingWorktree)
      if isThere {
        do {
          try await trash(path)
        } catch {
          throw TrashFailure(path: path, underlying: error)
        }
        // `forget` would unlink a directory still here; only the Trash may take it.
        guard !FileManager.default.fileExists(atPath: path.path) else {
          throw TrashFailure(path: path, underlying: TrashTookNothing())
        }
      }
      try await git.forget(worktree, in: project)
      try await WorktreeHooks.run(
        .postDelete, for: project, worktreePath: path, branch: branch, shellPath: shellPath,
        timeout: timeout, stopper: stopper, willRun: { onStep?(.postDeleteHook) })
    }
    if deletingBranch, let branch = worktree.branch {
      onStep?(.deletingBranch)
      try await deleteBranch(branch, in: project)
    }
  }

  public func deleteBranch(_ branch: String, force: Bool = false, in project: Project) async throws
  {
    do {
      try await git.deleteBranch(branch, force: force, in: project)
    } catch {
      throw BranchDeletionFailure(branch: branch, underlying: error)
    }
  }
}
