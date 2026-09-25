import Foundation
import MultishellCore
import MultishellGitKit
import MultishellProcess

extension AppModel {
  /// The lists to place, in run order. Only the repository's is held to the
  /// checkout, and a blank list of the user's own is what lets it stand.
  func fileLists(of project: Project, resolvedBy resolved: Project) -> [WorktreeFileList] {
    WorktreeFilePlacement.allCases.compactMap { placement in
      let listText = placement.listText(in: resolved.settings)
      guard !WorktreeFiles.paths(in: listText).isEmpty else { return nil }
      return WorktreeFileList(
        placement: placement, listText: listText,
        heldToRepository: placement.listText(in: project.settings).isEmpty)
    }
  }

  /// The file lists and the post-create hook run in the pane, not under the
  /// sheet: a build cache is not worth holding the window for.
  func beginWorktreeSetup(
    of worktree: Worktree, branch: String, in project: Project, shellPath: String?,
    lists: [WorktreeFileList]
  ) {
    let runningHook = WorktreeHooks.hasScript(.postCreate, in: project.settings)
    let first: WorktreeOperation.Step? =
      lists.first.map { WorktreeOperation.Step($0.placement) }
      ?? (runningHook ? .postCreateHook : nil)
    guard let first else { return }
    worktreeOperations.begin(first, on: worktree.id)
    // Made here, not in the task: a Cancel clicked before the task has run
    // would otherwise find nothing to stop.
    let stopper = ProcessStopper()
    stageHandles.arm(stopper, on: worktree.id)
    stageHandles.trackSetup(
      Task {
        await runWorktreeSetup(
          worktree, branch: branch, in: project, shellPath: shellPath, stopper: stopper,
          lists: lists, runningHook: runningHook)
      }, on: worktree.id)
  }

  /// What a new worktree gets before its first terminal: the file lists, then
  /// the post-create hook. A failure or a Cancel stops the stages after it.
  private func runWorktreeSetup(
    _ worktree: Worktree, branch: String, in project: Project, shellPath: String?,
    stopper: ProcessStopper, lists: [WorktreeFileList], runningHook: Bool
  ) async {
    var skipped: [String] = []
    for (index, list) in lists.enumerated() {
      let placement = list.placement
      let stage = WorktreeOperation.Step(placement)
      if index > 0 { worktreeOperations.advance(to: stage, on: worktree.id) }
      let placed = await placeListedFiles(
        list, into: worktree.path, for: project, stopper: stopper)
      guard let failure = placed.failure else {
        skipped += placed.skipped
        continue
      }
      endSetup(of: worktree, stopper: stopper)
      // The user's Cancel: the worktree is theirs, as after a stopped hook.
      // What had already failed is still said, Cancel excusing only the rest.
      if let stopped = failure as? WorktreeFileStopped {
        skipped += stopped.skipped
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
      return
    }
    // Said and gone past: an entry of the user's own naming elsewhere is a
    // typo worth a word, not worth their post-create hook.
    reportSkipped(skipped)
    guard runningHook else {
      endSetup(of: worktree, stopper: stopper)
      if let last = lists.last {
        finishStage(WorktreeOperation.Step(last.placement), of: worktree)
      }
      return
    }
    if !lists.isEmpty { worktreeOperations.advance(to: .postCreateHook, on: worktree.id) }
    await runPostCreateHook(
      for: worktree, branch: branch, in: project, shellPath: shellPath, stopper: stopper)
  }

  /// Lets go of the task and its stop handle, whichever stage ended.
  private func endSetup(of worktree: Worktree, stopper: ProcessStopper) {
    stageHandles.end(worktree.id, ifStillHeldBy: stopper)
    refreshBadges(of: worktree.id, in: worktree.projectID)
  }

  /// The stage ended, so the first tab held back while it ran opens now.
  /// Nothing where a removal now owns the entry; see `WorktreeOperations`.
  private func finishStage(_ step: WorktreeOperation.Step, of worktree: Worktree) {
    guard worktreeOperations.finish(step, on: worktree.id) else { return }
    openHeldBackTab(of: worktree)
  }

  /// A stage that failed says so on its pane, where it reads once the sheet
  /// has gone. An alert only where there is no pane to say it on.
  private func failStage(
    _ step: WorktreeOperation.Step, of worktree: Worktree, _ error: any Error,
    timedOut: Bool = false
  ) {
    // Gone while the stage ran, and the entry goes with it: paths are ids, so
    // the next worktree there would inherit an operation nothing can finish.
    guard workspace.worktree(worktree.id) != nil else {
      // `finish`, not `clear`: a removal that has since taken the entry owns
      // it, and this stage's late result is not the one to throw it away.
      worktreeOperations.finish(step, on: worktree.id)
      present(error)
      return
    }
    let shownInPane = worktreeOperations.fail(
      step, on: worktree.id, message: PresentedError(error).message, timedOut: timedOut)
    if !shownInPane { present(error) }
  }

  /// One of the project's file lists, before the post-create hook. Returns
  /// what went wrong rather than throwing, and what was skipped; off main.
  private func placeListedFiles(
    _ list: WorktreeFileList, into path: URL, for project: Project, stopper: ProcessStopper
  ) async -> (failure: (any Error)?, skipped: [String]) {
    guard let coordinator else { return (nil, []) }
    return await offMain {
      do {
        return (nil, try coordinator.placeFiles(list, for: project, into: path, stopper: stopper))
      } catch {
        return (error, [])
      }
    }
  }

  private func runPostCreateHook(
    for worktree: Worktree, branch: String, in project: Project, shellPath: String?,
    stopper: ProcessStopper
  ) async {
    defer { endSetup(of: worktree, stopper: stopper) }
    do {
      try await coordinator?.runPostCreate(
        for: project, worktreePath: worktree.path, branch: branch, shellPath: shellPath,
        timeout: workspace.hookTimeout, stopper: stopper)
    } catch {
      let stop = (error as? HookFailure)?.stop
      // Stopped by the user: the worktree is theirs to use, as after a
      // finish. A stop for any other reason is the timeout.
      if stop == .byUser {
        finishStage(.postCreateHook, of: worktree)
      } else {
        failStage(.postCreateHook, of: worktree, error, timedOut: stop != nil)
      }
      return
    }
    finishStage(.postCreateHook, of: worktree)
  }

  /// The first tab held back while the hook ran opens now under the create
  /// settings, and its shell starts even out of view; see terminals.md.
  func openHeldBackTab(of worktree: Worktree) {
    guard let current = workspace.worktree(worktree.id), !isBusy(current.id),
      workspace.tabs(in: current.id).isEmpty, opensTab(in: current, on: .onCreate),
      requireDirectory(of: current)
    else { return }
    addDefaultTab(in: current, on: .onCreate)
    warmWorktrees.insert(current.id)
    // The keyboard moves into the new pane only where the user is looking at
    // it; anywhere else the shell starts and the keyboard stays put.
    reconcileSessions(takingFocus: worktreeIDInView == current.id)
  }

  private func reportSkipped(_ entries: [String]) {
    guard !entries.isEmpty else { return }
    present(WorktreeFileSkipped(entries: entries))
  }
}
