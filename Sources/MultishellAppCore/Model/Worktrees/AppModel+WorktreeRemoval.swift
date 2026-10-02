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
      let changesUnread = await !readsFreshStatusInTime(of: worktree.id)
      removalsAwaitingStatus.remove(worktree.id)
      let isLatest = latestRemovalRequest == worktree.id
      if isLatest { latestRemovalRequest = nil }
      // A late read must not swap the dialog up, or a newer click's, for its own.
      guard isLatest, pendingWorktreeRemoval == nil, let current = workspace.worktree(worktree.id),
        !isBusy(current.id)
      else { return }
      switch removalDecision(for: current, changesUnread: changesUnread) {
      case .ask(let pending): pendingWorktreeRemoval = pending
      case .remove(let deletingBranch):
        await removeWorktree(current, deletingBranch: deletingBranch)
      }
    }
  }

  /// Whether a read begun after the click landed within the wait. An earlier
  /// removal's read still running is waited out first rather than stacked on.
  private func readsFreshStatusInTime(of id: Worktree.ID) async -> Bool {
    let deadline = ContinuousClock.now + removalStatusWait
    if let earlier = removalStatusReads[id], await earlier.value(within: removalStatusWait) == nil {
      return false
    }
    return await startRemovalStatusRead(of: id).value(within: deadline - .now) == true
  }

  private func startRemovalStatusRead(of id: Worktree.ID) -> Task<Bool, Never> {
    let statusRead = Task { await refreshStatus(of: id, forced: true) }
    removalStatusReads[id] = statusRead
    // A worktree re-made at the path may have a read of its own by then.
    Task {
      _ = await statusRead.value
      if removalStatusReads[id] == statusRead { removalStatusReads[id] = nil }
    }
    return statusRead
  }

  private func removalDecision(
    for worktree: Worktree, changesUnread: Bool = false
  ) -> PendingWorktreeRemoval.Decision {
    PendingWorktreeRemoval.decide(
      worktree, customName: customName(of: worktree),
      confirms: workspace.confirmsWorktreeRemoval,
      alwaysDeletesBranch: workspace.deletesBranchWithWorktree,
      trashes: workspace.trashesRemovedWorktrees, mergeState: mergeState(of: worktree),
      changesUnread: changesUnread)
  }

  /// The dialog's answer: the index of the button chosen, `nil` for Cancel.
  /// The task is the removal, when one was chosen.
  @discardableResult
  public func answerWorktreeRemoval(
    _ pending: PendingWorktreeRemoval, choice: Int?
  ) -> Task<Void, Never>? {
    pendingWorktreeRemoval = nil
    guard let choice, pending.choices.indices.contains(choice) else { return nil }
    let deletesBranch = pending.choices[choice].deletesBranch
    return Task { await confirmWorktreeRemoval(pending, deletingBranch: deletesBranch) }
  }

  /// Trashing or deleting as the dialog's message said, even if the setting
  /// changed while it was up.
  func confirmWorktreeRemoval(
    _ pending: PendingWorktreeRemoval, deletingBranch: Bool
  ) async {
    await removeWorktree(pending.worktree, deletingBranch: deletingBranch, trashes: pending.trashes)
  }

  /// What the confirmation should warn about, beyond the removal itself.
  public func worktreeRemovalWarning(for pending: PendingWorktreeRemoval) -> String? {
    PendingWorktreeRemoval.warning(
      changedFiles: statuses[pending.worktree.id]?.changedFiles ?? 0,
      changesUnread: pending.changesUnread,
      liveTerminals: liveTerminalCount(in: pending.worktree.id),
      trashes: pending.trashes)
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
    let effective = effectiveProject(project)
    let trashes = trashes ?? workspace.trashesRemovedWorktrees
    worktreeOperations.begin(
      .init(WorktreeRemovalStep.first(for: effective), trashes: trashes), on: worktree.id)
    let stopper = ProcessStopper()
    stageHandles.holdStopper(stopper, on: worktree.id)
    defer { stageHandles.releaseStopper(worktree.id, ifStillHeldBy: stopper) }
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
          await self?.forceDeleteBranch(branch, of: project)
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
  private func forceDeleteBranch(_ branch: String, of project: Project) async {
    guard let coordinator else { return }
    do {
      try await coordinator.deleteBranch(branch, force: true, in: project)
    } catch {
      present(error)
    }
  }
}
