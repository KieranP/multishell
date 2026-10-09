import Foundation
import MultishellCore
import MultishellGitKit
import MultishellProcess

extension AppModel {
  /// The lists to place, in run order. Only the repository's is held to the
  /// checkout, and a blank list of the user's own is what lets it stand.
  func fileLists(of project: Project, inEffect effective: Project) -> [WorktreeFileList] {
    WorktreeFilePlacement.allCases.compactMap { placement in
      let listText = placement.listText(in: effective.settings)
      guard !WorktreeFiles.paths(in: listText).isEmpty else { return nil }
      return WorktreeFileList(
        placement: placement,
        listText: listText,
        isRepositoryList: placement.listText(in: project.settings).isEmpty,
      )
    }
  }

  /// The file lists and the post-create hook run in the pane, not under the
  /// sheet: a build cache is not worth holding the window for.
  func beginWorktreeSetup(
    of worktree: Worktree,
    branch: String,
    in effective: Project,
    shellPath: String?,
    lists: [WorktreeFileList],
  ) {
    let runsPostCreateHook = WorktreeHooks.hasScript(.postCreate, in: effective.settings)
    let first: WorktreeOperation.Stage? =
      lists.first.map { WorktreeOperation.Stage($0.placement) }
      ?? (runsPostCreateHook ? .postCreateHook : nil)
    guard let first else { return }
    worktreeOperations.begin(first, on: worktree.id)
    // Made here, not in the task: a Cancel clicked before the task has run
    // would otherwise find nothing to stop.
    let stopper = ProcessStopper()
    stageHandles.holdStopper(stopper, on: worktree.id)
    stageHandles.trackSetup(
      Task {
        await runWorktreeSetup(
          worktree,
          branch: branch,
          in: effective,
          shellPath: shellPath,
          stopper: stopper,
          lists: lists,
          runsPostCreateHook: runsPostCreateHook,
        )
      },
      on: worktree.id,
    )
  }

  /// What a new worktree gets before its first terminal: the file lists, then
  /// the post-create hook. A failure or a Cancel stops the stages after it.
  private func runWorktreeSetup(
    _ worktree: Worktree,
    branch: String,
    in effective: Project,
    shellPath: String?,
    stopper: ProcessStopper,
    lists: [WorktreeFileList],
    runsPostCreateHook: Bool,
  ) async {
    var skipped: [String] = []
    for (index, list) in lists.enumerated() {
      if index > 0 {
        worktreeOperations.advance(to: WorktreeOperation.Stage(list.placement), on: worktree.id)
      }
      let placed = await placeListedFiles(
        list,
        into: worktree.path,
        for: effective,
        stopper: stopper,
      )
      guard let failure = placed.failure else {
        skipped += placed.skipped
        continue
      }
      endSetup(of: worktree, stopper: stopper)
      finishOrFailFileListStage(of: worktree, placing: list.placement, failure, skipped: skipped)
      return
    }
    // Said and gone past: an entry of the user's own naming elsewhere is a
    // typo worth a word, not worth their post-create hook.
    reportSkipped(skipped)
    guard runsPostCreateHook else {
      endSetup(of: worktree, stopper: stopper)
      if let last = lists.last {
        finishStage(WorktreeOperation.Stage(last.placement), of: worktree)
      }
      return
    }
    if !lists.isEmpty { worktreeOperations.advance(to: .postCreateHook, on: worktree.id) }
    await runPostCreateHook(
      for: worktree,
      branch: branch,
      in: effective,
      shellPath: shellPath,
      stopper: stopper,
    )
  }

  /// Lets go of the task and its stop handle, whichever stage ended, and reads
  /// the badges again for what the stages wrote.
  private func endSetup(of worktree: Worktree, stopper: ProcessStopper) {
    stageHandles.endSetup(stopper, on: worktree.id)
    refreshBadges(of: worktree.id, in: worktree.projectID)
  }

  /// One of the project's file lists, before the post-create hook. Returns
  /// what went wrong rather than throwing, and what was skipped; off main.
  private func placeListedFiles(
    _ list: WorktreeFileList,
    into path: URL,
    for effective: Project,
    stopper: ProcessStopper,
  ) async -> (failure: (any Error)?, skipped: [String]) {
    guard let coordinator else { return (nil, []) }
    return await runOnDispatch {
      do {
        return (
          nil, try coordinator.placeFiles(list, for: effective, into: path, stopper: stopper),
        )
      } catch {
        return (error, [])
      }
    }
  }

  private func runPostCreateHook(
    for worktree: Worktree,
    branch: String,
    in effective: Project,
    shellPath: String?,
    stopper: ProcessStopper,
  ) async {
    defer { endSetup(of: worktree, stopper: stopper) }
    do {
      try await coordinator?.runPostCreateHook(
        for: effective,
        worktreePath: worktree.path,
        branch: branch,
        shellPath: shellPath,
        timeout: workspace.projectHookTimeout,
        stopper: stopper,
      )
    } catch {
      let stopReason = (error as? HookFailure)?.stopReason
      // Stopped by the user: the worktree is theirs to use, as after a
      // finish. A stop for any other reason is the timeout.
      if stopReason == .byUser {
        finishStage(.postCreateHook, of: worktree)
      } else {
        failStage(.postCreateHook, of: worktree, error, didTimeOut: stopReason != nil)
      }
      return
    }
    finishStage(.postCreateHook, of: worktree)
  }
}
