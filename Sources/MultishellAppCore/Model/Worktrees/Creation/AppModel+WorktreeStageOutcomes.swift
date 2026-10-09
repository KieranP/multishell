import MultishellCore
import MultishellGitKit

/// What a setup stage's end does: the held-back tab, or the failure said on
/// the pane, and the entries a file list skipped.
extension AppModel {
  /// A file list that stopped short, with what the lists before it skipped.
  func finishOrFailFileListStage(
    of worktree: Worktree, placing placement: WorktreeFilePlacement, _ failure: any Error,
    skipped: [String]
  ) {
    let stage = WorktreeOperation.Stage(placement)
    // The user's Cancel: the worktree is theirs, as after a stopped hook.
    // What had already failed is still said, Cancel excusing only the rest.
    if let stopped = failure as? WorktreeFileStopped {
      let skipped = skipped + stopped.skipped
      if stopped.failures.isEmpty {
        reportSkipped(skipped)
        finishStage(stage, of: worktree)
      } else {
        failStage(
          stage, of: worktree,
          WorktreeFileFailure(placement: placement, failures: stopped.failures)
            .including(skipped: skipped))
      }
    } else if let failed = failure as? WorktreeFileFailure {
      failStage(stage, of: worktree, failed.including(skipped: skipped))
    } else {
      reportSkipped(skipped)
      failStage(stage, of: worktree, failure)
    }
  }

  /// The stage ended, so the first tab held back while it ran opens now.
  /// Nothing where a removal now owns the entry; see `WorktreeOperations`.
  func finishStage(_ stage: WorktreeOperation.Stage, of worktree: Worktree) {
    guard worktreeOperations.finish(stage, on: worktree.id) else { return }
    openHeldBackTab(of: worktree)
  }

  /// A stage that failed says so on its pane, where it reads once the sheet
  /// has gone. An alert only where there is no pane to say it on.
  func failStage(
    _ stage: WorktreeOperation.Stage, of worktree: Worktree, _ error: any Error,
    didTimeOut: Bool = false
  ) {
    // Gone while the stage ran, and the entry goes with it: paths are ids, so
    // the next worktree there would inherit an operation nothing can finish.
    guard workspace.worktree(worktree.id) != nil else {
      // `finish`, not `clear`: a removal that has since taken the entry owns
      // it, and this stage's late result is not the one to throw it away.
      worktreeOperations.finish(stage, on: worktree.id)
      present(error)
      return
    }
    let shownInPane = worktreeOperations.fail(
      stage, on: worktree.id, message: PresentedError(error).message, didTimeOut: didTimeOut)
    if !shownInPane { present(error) }
  }

  /// The first tab held back while the hook ran opens now under the create
  /// settings, and its shell starts even out of view; see terminals.md.
  func openHeldBackTab(of worktree: Worktree) {
    defer { newWorktreeFirstTabs[worktree.id] = nil }
    guard let current = workspace.worktree(worktree.id),
      wantsFirstTab(in: current, for: .onCreate), requireDirectory(of: current)
    else { return }
    addDefaultTab(in: current, for: .onCreate)
    warmWorktrees.insert(current.id)
    // The keyboard moves into the new pane only where the user is looking at
    // it; anywhere else the shell starts and the keyboard stays put.
    reconcileSessions(takingFocus: worktreeIDInView == current.id)
  }

  func reportSkipped(_ entries: [String]) {
    guard !entries.isEmpty else { return }
    present(WorktreeFileSkipped(entries: entries))
  }
}
