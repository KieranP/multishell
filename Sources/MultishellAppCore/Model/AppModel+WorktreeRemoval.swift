import Foundation
import MultishellCore
import MultishellGitKit
import MultishellProcess

extension AppModel {
  public func setConfirmsWorktreeRemoval(_ enabled: Bool) {
    store.setConfirmsWorktreeRemoval(enabled)
  }

  public func setDeletesBranchWithWorktree(_ enabled: Bool) {
    store.setDeletesBranchWithWorktree(enabled)
  }

  public func setTrashesRemovedWorktrees(_ enabled: Bool) {
    store.setTrashesRemovedWorktrees(enabled)
  }

  /// Entry point from the UI, asking first unless the settings have settled
  /// both questions. Nothing while an operation is already running there.
  public func requestRemoval(of worktree: Worktree) {
    guard worktree.isRemovable, !isBusy(worktree.id) else { return }
    switch PendingWorktreeRemoval.decide(
      worktree, customName: customName(of: worktree),
      confirms: workspace.confirmsWorktreeRemoval,
      alwaysDeletesBranch: workspace.deletesBranchWithWorktree,
      trashes: workspace.trashesRemovedWorktrees, mergeState: mergeState(of: worktree))
    {
    case .ask(let pending):
      pendingRemoval = pending
    case .remove(let deletingBranch):
      Task { await removeWorktree(worktree, deletingBranch: deletingBranch) }
    }
  }

  /// The dialog's answer, trashing or deleting as its message said even if
  /// the setting changed while it was up.
  public func confirmRemoval(_ pending: PendingWorktreeRemoval, deletingBranch: Bool) async {
    await removeWorktree(pending.worktree, deletingBranch: deletingBranch, trashes: pending.trashes)
  }

  /// What the confirmation should warn about, beyond the removal itself.
  public func removalWarning(for worktree: Worktree) -> String? {
    PendingWorktreeRemoval.warning(
      changedFiles: statuses[worktree.id]?.changedFiles ?? 0,
      liveTerminals: liveTerminalCount(in: worktree.id),
      trashes: workspace.trashesRemovedWorktrees)
  }

  /// The pane shows each stage while this runs. What a failed stage does is
  /// `RemovalFailure`'s decision; this attaches the retry it names.
  public func removeWorktree(
    _ worktree: Worktree, deletingBranch: Bool = false, trashes: Bool? = nil
  ) async {
    guard let worktrees, let project = workspace.project(worktree.projectID) else { return }
    if renamingWorktreeID == worktree.id { renamingWorktreeID = nil }
    let resolved = resolved(project)
    let trashes = trashes ?? workspace.trashesRemovedWorktrees
    worktreeOperations.begin(
      .init(WorktreeRemovalStep.first(for: resolved), trashes: trashes), on: worktree.id)
    let stopper = ProcessStopper()
    workInFlight.arm(stopper, on: worktree.id)
    defer { workInFlight.disarm(worktree.id, stoppedBy: stopper) }
    do {
      try await worktrees.remove(
        worktree, deletingBranch: deletingBranch, in: resolved,
        shellPath: workspace.defaultShell(for: project),
        trash: { [weak self] url in
          if trashes { try await self?.moveToTrash(url) } else { try await Self.delete(url) }
        },
        timeout: workspace.hookTimeout, stopper: stopper,
        onStep: { [weak self] step in
          Task { @MainActor in
            self?.worktreeOperations.advance(to: .init(step, trashes: trashes), on: worktree.id)
          }
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
        if let retry, case .deleteBranchAnyway(let branch) = retry {
          presented.retryLabel = retry.label
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
    reconcileSessions(takingFocus: true)
  }

  /// The Trash where it takes the directory, deletion where it will not: the
  /// removal was confirmed either way; see Docs/design/worktrees.md.
  func moveToTrash(_ url: URL) async throws {
    let platform = self.platform
    let trashed = await Self.offMain { Result { try platform.moveToTrash(url) } }
    guard case .failure(let error) = trashed else { return }
    platform.log("\(url.path) could not be moved to the Trash (\(error)); deleting it")
    try await Self.delete(url)
  }

  nonisolated static func delete(_ url: URL) async throws {
    try await offMain { Result { try FileManager.default.removeItem(at: url) } }.get()
  }

  /// The branch alone, after a removal that left it behind.
  func deleteBranch(_ branch: String, of project: Project, force: Bool) async {
    guard let worktrees else { return }
    do {
      try await worktrees.deleteBranch(branch, force: force, in: project)
    } catch {
      report(error)
    }
  }
}
