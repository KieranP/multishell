import Foundation
import MultishellCore
import MultishellGitKit
import MultishellProcess

extension AppModel {
  /// The pane shows each stage while this runs. What a failed stage does is
  /// `PresentedRemovalFailure`'s decision; this attaches the retry it names.
  func removeWorktree(
    _ worktree: Worktree,
    deletesBranch: Bool,
    trashes: Bool? = nil,
  ) async {
    // Here, before the stage begins, as each request reaches this in a Task of its own.
    guard let coordinator, let project = workspace.project(worktree.projectID),
      !isBusy(worktree.id)
    else { return }
    if renamingWorktreeID == worktree.id { renamingWorktreeID = nil }
    let effective = effectiveProject(project)
    let trashes = trashes ?? workspace.trashesRemovedWorktrees
    worktreeOperations.begin(
      .init(WorktreeRemovalStep.first(for: effective), trashes: trashes),
      on: worktree.id,
    )
    let stopper = ProcessStopper()
    stageHandles.holdStopper(stopper, on: worktree.id)
    defer { stageHandles.releaseStopper(stopper, on: worktree.id) }
    do {
      try await coordinator.remove(
        worktree,
        in: effective,
        trash: { [weak self] url in
          if trashes {
            try await self?.trashOrDelete(url)
          } else {
            try await url.removeFromDisk()
          }
        },
        deletesBranch: deletesBranch,
        shellPath: workspace.effectiveShellPath(for: effective),
        timeout: workspace.projectHookTimeout,
        stopper: stopper,
        onStep: { [weak self] step in
          Task { @MainActor in
            self?.worktreeOperations.advance(to: .init(step, trashes: trashes), on: worktree.id)
          }
        },
      )
    } catch {
      let worktreeIsGone = reportRemovalFailure(
        error,
        of: worktree,
        deletesBranch: deletesBranch,
        in: project,
      )
      guard worktreeIsGone else { return }
    }
    worktreeOperations.clear(worktree.id)
    await refreshWorktrees(of: project)
    await rearmWatcher()
    reconcileSessions(takingFocus: true)
  }

  /// Says what went wrong where `PresentedRemovalFailure` puts it. `true` where the
  /// worktree went regardless, so the refresh after a removal still runs.
  private func reportRemovalFailure(
    _ error: any Error,
    of worktree: Worktree,
    deletesBranch: Bool,
    in project: Project,
  ) -> Bool {
    let failure = PresentedRemovalFailure(
      error,
      deletingBranch: deletesBranch ? worktree.branch : nil,
    )
    switch failure {
    case .stopped:
      worktreeOperations.clear(worktree.id)
      return false

    case .vetoed(let message, let didTimeOut):
      if !worktreeOperations.fail(
        .preDeleteHook,
        on: worktree.id,
        message: message,
        didTimeOut: didTimeOut,
      ) {
        present(error)
      }
      return false

    case .alert(let title, let message, let retry, let wasWorktreeRemoved):
      var presented = PresentedError(title: title, message: message)
      if let retry, case .deleteBranchAnyway(let branch) = retry {
        presented.retry = .init(label: retry.label) { [weak self] in
          await self?.forceDeleteBranch(branch, of: project)
        }
      }
      presentedError = presented
      if !wasWorktreeRemoved { worktreeOperations.clear(worktree.id) }
      return wasWorktreeRemoved
    }
  }

  /// The Trash where it takes the directory, deletion where it will not: the
  /// removal was confirmed either way; see Docs/design/worktrees.md.
  private func trashOrDelete(_ url: URL) async throws {
    let platform = self.platform
    let trashed = await runOnDispatch { Result { try platform.moveToTrash(url) } }
    guard case .failure(let error) = trashed else { return }
    platform.log("\(url.path) could not be moved to the Trash (\(error)); deleting it")
    try await url.removeFromDisk()
  }

  /// The branch alone, after a removal that left it behind.
  private func forceDeleteBranch(_ branch: String, of project: Project) async {
    guard let coordinator else { return }
    do {
      try await coordinator.deleteBranch(branch, in: project, force: true)
    } catch {
      present(error)
    }
  }
}
