import Foundation
import MultishellCore
import MultishellGitKit
import MultishellProcess

// MARK: - Removing a worktree, its directory and its branch

extension AppModel {
  public func setConfirmsWorktreeRemoval(_ enabled: Bool) {
    store.setConfirmsWorktreeRemoval(enabled)
  }

  public func setDeletesBranchWithWorktree(_ enabled: Bool) {
    store.setDeletesBranchWithWorktree(enabled)
  }

  /// Entry point from the UI. Asks first unless the settings have settled
  /// both the removal and the branch; see `PendingWorktreeRemoval.decide`.
  /// Nothing while a create or remove is already running there.
  public func requestRemoval(of worktree: Worktree) {
    guard !isBusy(worktree.id) else { return }
    switch PendingWorktreeRemoval.decide(
      worktree, customName: customName(of: worktree),
      confirms: workspace.confirmsWorktreeRemoval,
      alwaysDeletesBranch: workspace.deletesBranchWithWorktree,
      mergeState: mergeState(of: worktree))
    {
    case .ask(let pending):
      pendingRemoval = pending
    case .remove(let deletingBranch):
      Task { await removeWorktree(worktree, deletingBranch: deletingBranch) }
    }
  }

  /// What the confirmation should warn about, beyond the removal itself.
  public func removalWarning(for worktree: Worktree) -> String? {
    PendingWorktreeRemoval.warning(
      changedFiles: statuses[worktree.id]?.changedFiles ?? 0,
      liveTerminals: liveTerminalCount(in: worktree.id))
  }

  /// The pane shows each stage while this runs: the pre-delete hook, the
  /// directory to the Trash and `git worktree prune`, the post-delete hook,
  /// the branch. What a failed stage does to the pane and the alert is
  /// `RemovalFailure`'s decision; this attaches the retry it names and puts
  /// the worktree back if it is still there.
  public func removeWorktree(_ worktree: Worktree, deletingBranch: Bool = false) async {
    guard let worktrees, let project = workspace.project(worktree.projectID) else { return }
    if renamingWorktreeID == worktree.id { renamingWorktreeID = nil }
    let resolved = resolved(project)
    worktreeOperations.begin(.init(WorktreeRemovalStep.first(for: resolved)), on: worktree.id)
    let stopper = ProcessStopper()
    hookStoppers[worktree.id] = stopper
    defer {
      if hookStoppers[worktree.id] === stopper { hookStoppers[worktree.id] = nil }
    }
    do {
      try await worktrees.remove(
        worktree, deletingBranch: deletingBranch, in: resolved,
        shellPath: workspace.defaultShell(for: project),
        trash: { [weak self] url in try await self?.moveToTrash(url) },
        timeout: workspace.hookTimeout, stopper: stopper,
        onStep: { [weak self] step in
          Task { @MainActor in self?.worktreeOperations.advance(to: .init(step), on: worktree.id) }
        })
    } catch {
      let failure = RemovalFailure.describe(
        error, deletingBranch: deletingBranch ? worktree.branch : nil)
      switch failure {
      case .stopped:
        worktreeOperations.clear(worktree.id)
        return
      case .vetoed(let message, let timedOut):
        if !worktreeOperations.fail(
          .preDeleteHook, on: worktree.id, message: message, timedOut: timedOut)
        {
          report(error)
        }
        return
      case .alert(let title, let message, let retry, let worktreeRemoved):
        var presented = PresentedError(title: title, message: message)
        if case .deleteBranchAnyway(let branch) = retry {
          presented.retryLabel = "Delete Branch Anyway"
          presented.retry = { [weak self] in
            await self?.deleteBranch(branch, of: project, force: true)
          }
        }
        presentedError = presented
        guard worktreeRemoved else {
          worktreeOperations.clear(worktree.id)
          return
        }
      }
    }
    worktreeOperations.clear(worktree.id)
    await refresh(project)
    await rearmWatcher()
    sync()
  }

  /// The Trash where it takes the directory; deletion where it will not, a
  /// volume without a `.Trashes` being the usual reason. The removal was
  /// confirmed either way, and the alternative is a worktree that cannot be
  /// removed from the app at all.
  func moveToTrash(_ url: URL) throws {
    do {
      try platform.moveToTrash(url)
    } catch {
      platform.log("\(url.path) could not be moved to the Trash (\(error)); deleting it")
      try FileManager.default.removeItem(at: url)
    }
  }

  /// The branch alone, after a removal that left it behind.
  public func deleteBranch(_ branch: String, of project: Project, force: Bool) async {
    guard let worktrees else { return }
    do {
      try await worktrees.deleteBranch(branch, force: force, in: project)
    } catch {
      report(error)
    }
  }
}
