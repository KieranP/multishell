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

  /// Asks first unless the settings have settled both questions; nothing while an
  /// operation runs there. The task ends once the dialog is up or the removal is over.
  @discardableResult
  public func requestWorktreeRemoval(of worktree: Worktree) -> Task<Void, Never>? {
    guard worktree.isRemovable, !isBusy(worktree.id) else { return nil }
    if case .remove(let deletingBranch) = removalDecision(for: worktree) {
      return Task { await removeWorktree(worktree, deletingBranch: deletingBranch) }
    }
    latestRemovalRequest = worktree.id
    guard removalsAwaitingStatus.insert(worktree.id).inserted else { return nil }
    // Any row's status may be as old as the pace allows, and the dialog,
    // built once, warns of the changed files that status counts.
    return Task {
      await refreshStatus(of: worktree.id, forced: true)
      removalsAwaitingStatus.remove(worktree.id)
      let isLatest = latestRemovalRequest == worktree.id
      if isLatest { latestRemovalRequest = nil }
      // A late read must not swap the dialog up, or a newer click's, for its own.
      guard isLatest, pendingWorktreeRemoval == nil, let current = workspace.worktree(worktree.id),
        !isBusy(current.id)
      else { return }
      switch removalDecision(for: current) {
      case .ask(let pending): pendingWorktreeRemoval = pending
      case .remove(let deletingBranch):
        await removeWorktree(current, deletingBranch: deletingBranch)
      }
    }
  }

  private func removalDecision(for worktree: Worktree) -> PendingWorktreeRemoval.Decision {
    PendingWorktreeRemoval.decide(
      worktree, customName: customName(of: worktree),
      confirms: workspace.confirmsWorktreeRemoval,
      alwaysDeletesBranch: workspace.deletesBranchWithWorktree,
      trashes: workspace.trashesRemovedWorktrees, mergeState: mergeState(of: worktree))
  }

  /// The dialog's answer, trashing or deleting as its message said even if
  /// the setting changed while it was up.
  public func confirmWorktreeRemoval(
    _ pending: PendingWorktreeRemoval, deletingBranch: Bool
  ) async {
    await removeWorktree(pending.worktree, deletingBranch: deletingBranch, trashes: pending.trashes)
  }

  /// What the confirmation should warn about, beyond the removal itself.
  public func worktreeRemovalWarning(for worktree: Worktree) -> String? {
    PendingWorktreeRemoval.warning(
      changedFiles: statuses[worktree.id]?.changedFiles ?? 0,
      liveTerminals: liveTerminalCount(in: worktree.id),
      trashes: workspace.trashesRemovedWorktrees)
  }

  /// The pane shows each stage while this runs. What a failed stage does is
  /// `WorktreeRemovalFailure`'s decision; this attaches the retry it names.
  func removeWorktree(
    _ worktree: Worktree, deletingBranch: Bool = false, trashes: Bool? = nil
  ) async {
    // Here, before the stage begins, as each request reaches this in a Task of its own.
    guard let coordinator, let project = workspace.project(worktree.projectID),
      !isBusy(worktree.id)
    else { return }
    if renamingWorktreeID == worktree.id { renamingWorktreeID = nil }
    let effective = withEffectiveSettings(project)
    let trashes = trashes ?? workspace.trashesRemovedWorktrees
    worktreeOperations.begin(
      .init(WorktreeRemovalStep.first(for: effective), trashes: trashes), on: worktree.id)
    let stopper = ProcessStopper()
    stageHandles.arm(stopper, on: worktree.id)
    defer { stageHandles.disarm(worktree.id, ifStillHeldBy: stopper) }
    do {
      try await coordinator.remove(
        worktree, deletingBranch: deletingBranch, in: effective,
        shellPath: workspace.effectiveShellPath(for: project),
        trash: { [weak self] url in
          if trashes {
            try await self?.trashOrDelete(url)
          } else {
            try await deleteDirectory(url)
          }
        },
        timeout: workspace.hookTimeout, stopper: stopper,
        onStep: { [weak self] step in
          Task { @MainActor in
            self?.worktreeOperations.advance(to: .init(step, trashes: trashes), on: worktree.id)
          }
        })
    } catch {
      let worktreeIsGone = reportRemovalFailure(
        error, of: worktree, deletingBranch: deletingBranch, in: project)
      guard worktreeIsGone else { return }
    }
    worktreeOperations.clear(worktree.id)
    await refreshWorktrees(of: project)
    await rearmWatcher()
    reconcileSessions(takingFocus: true)
  }

  /// Says what went wrong where `WorktreeRemovalFailure` puts it. `true` where the
  /// worktree went regardless, so the refresh after a removal still runs.
  private func reportRemovalFailure(
    _ error: any Error, of worktree: Worktree, deletingBranch: Bool, in project: Project
  ) -> Bool {
    let failure = WorktreeRemovalFailure(
      error, deletingBranch: deletingBranch ? worktree.branch : nil)
    switch failure {
    case .stopped:
      worktreeOperations.clear(worktree.id)
      return false
    case .vetoed(let message, let timedOut):
      if !worktreeOperations.fail(
        .preDeleteHook, on: worktree.id, message: message, timedOut: timedOut)
      {
        present(error)
      }
      return false
    case .alert(let title, let message, let retry, let worktreeRemoved):
      var presented = PresentedError(title: title, message: message)
      if let retry, case .deleteBranchAnyway(let branch) = retry {
        presented.retry = .init(label: retry.label) { [weak self] in
          await self?.deleteBranch(branch, of: project, force: true)
        }
      }
      presentedError = presented
      if !worktreeRemoved { worktreeOperations.clear(worktree.id) }
      return worktreeRemoved
    }
  }

  /// The Trash where it takes the directory, deletion where it will not: the
  /// removal was confirmed either way; see Docs/design/worktrees.md.
  private func trashOrDelete(_ url: URL) async throws {
    let platform = self.platform
    let trashed = await offMain { Result { try platform.moveToTrash(url) } }
    guard case .failure(let error) = trashed else { return }
    platform.log("\(url.path) could not be moved to the Trash (\(error)); deleting it")
    try await deleteDirectory(url)
  }

  /// The branch alone, after a removal that left it behind.
  private func deleteBranch(_ branch: String, of project: Project, force: Bool) async {
    guard let coordinator else { return }
    do {
      try await coordinator.deleteBranch(branch, force: force, in: project)
    } catch {
      present(error)
    }
  }
}
