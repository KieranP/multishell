import Foundation
import MultishellCore
import MultishellGitKit
import MultishellProcess

extension AppModel {
  /// Opens the sheet for `project`, or the one being worked in. With several
  /// projects and nothing selected the picker starts blank.
  public func requestNewWorktree(in project: Project? = nil) {
    newWorktreeRequest = NewWorktreeRequest(projectID: (project ?? activeProject)?.id)
  }

  public func plannedPath(
    forBranch branch: String, createBranch: Bool, in project: Project
  )
    -> URL?
  {
    worktrees?.plannedPath(
      forBranch: branch, createBranch: createBranch, in: project,
      settings: worktreeSettings(for: project))
  }

  public func hasCommits(_ project: Project) async -> Bool {
    await worktrees?.hasCommits(project) ?? false
  }

  public func branches(of project: Project) async -> (local: [String], remote: [String]) {
    (
      (try? await worktrees?.localBranches(project)) ?? [],
      (try? await worktrees?.remoteBranches(project)) ?? []
    )
  }

  public func currentBranch(of project: Project) async -> String {
    (try? await worktrees?.currentBranch(project)) ?? "HEAD"
  }

  /// The sheet's Cancel while the pre-create hook or git runs. A stopped
  /// add leaves what git had made; the next refresh lists it or not.
  public func cancelWorktreeCreation() {
    creationStopper?.stop()
  }

  /// A step reported by the create `stopper` belongs to, and dropped once
  /// that create has ended: a late one would silence the shared-hooks question.
  func noteCreationStep(_ step: WorktreeCreationStep, of stopper: ProcessStopper) {
    guard creationStopper === stopper else { return }
    worktreeCreationStep = step
  }

  /// Returns once the worktree exists and is selected, or the create failed.
  /// The post-create hook runs on in the pane; see `WorktreeOperation`.
  public func createWorktree(
    branch: String,
    basedOn startPoint: String?,
    createBranch: Bool,
    in project: Project
  ) async {
    // The workspace, not the value handed in: a sheet held open across a
    // removal would add a worktree nothing in the app lists.
    guard let worktrees, workspace.project(project.id) != nil else { return }
    let resolved = resolved(project)
    let settings = worktreeSettings(for: project)
    let shell = workspace.defaultShell(for: project)
    // The row can arrive mid-checkout: git writes its record before the
    // first file, and that directory is watched. See worktrees.md.
    let claimed = claimConstruction(
      of: worktrees.plannedPath(
        forBranch: branch, createBranch: createBranch, in: resolved, settings: settings))
    let stopper = ProcessStopper()
    creationStopper = stopper
    defer {
      worktreeCreationStep = nil
      creationStopper = nil
      if let claimed { endConstruction(of: claimed, in: project) }
    }
    let path: URL
    do {
      path = try await worktrees.add(
        branch: branch,
        basedOn: startPoint,
        createBranch: createBranch,
        in: resolved,
        settings: settings,
        shellPath: shell,
        timeout: workspace.hookTimeout,
        stopper: stopper,
        onStep: { [weak self] step in
          Task { @MainActor in self?.noteCreationStep(step, of: stopper) }
        }
      )
    } catch {
      // The user's Cancel, of the hook or of git itself: nothing to report.
      let stop = (error as? HookFailure)?.stop ?? (error as? ProcessFailure)?.stop
      if stop != .stopped { report(error) }
      return
    }
    await refresh(project)
    await rearmWatcher()
    // git reports resolved paths, so on a symlinked volume the directory we
    // asked for and the one it lists can differ. Fall back to the branch.
    let name = WorktreeCoordinator.branchName(
      branch, createBranch: createBranch, settings: settings)
    guard
      let created = workspace.worktree(path.standardizedFileURL.path)
        ?? workspace.worktrees(of: project.id).first(where: { $0.branch == name })
    else { return }
    // The file lists and the hook run in the pane, not under the sheet: a
    // build cache is not worth holding the window for.
    let placements = WorktreePlacement.allCases.filter {
      !WorktreeFiles.paths(in: $0.paths(in: resolved.settings)).isEmpty
    }
    let hasHook = WorktreeHooks.hasScript(resolved.settings.postCreateHook)
    let first: WorktreeOperation.Step? =
      placements.first.map(WorktreeOperation.Step.init) ?? (hasHook ? .postCreateHook : nil)
    if let first {
      worktreeOperations.begin(first, on: created.id)
      // Made here, not in the task: a Cancel clicked before the task has
      // run would otherwise find nothing to stop.
      let stopper = ProcessStopper()
      stageStoppers[created.id] = stopper
      worktreeSetups[created.id] = Task {
        await prepareWorktree(
          created, branch: name, in: resolved, shellPath: shell, stopper: stopper,
          placements: placements, runningHook: hasHook)
      }
    }
    select(created, openingFirstTab: .onCreate)
  }

  /// What a new worktree gets before its first terminal: the file lists, then
  /// the post-create hook. A failure or a Cancel stops the stages after it.
  private func prepareWorktree(
    _ worktree: Worktree, branch: String, in project: Project, shellPath: String?,
    stopper: ProcessStopper, placements: [WorktreePlacement], runningHook: Bool
  ) async {
    for (index, placement) in placements.enumerated() {
      let stage = WorktreeOperation.Step(placement)
      if index > 0 { worktreeOperations.advance(to: stage, on: worktree.id) }
      guard
        let failure = await placeListedFiles(
          placement, into: worktree.path, for: project, stopper: stopper)
      else { continue }
      endSetup(of: worktree, stopper: stopper)
      // The user's Cancel: the worktree is theirs, as after a stopped hook.
      // What had already failed is still said, Cancel excusing only the rest.
      if let stopped = failure as? WorktreeFilesStopped {
        if stopped.failures.isEmpty {
          finishStage(stage, of: worktree)
        } else {
          failStage(
            stage, of: worktree,
            WorktreeFileFailure(placement: placement, items: stopped.failures))
        }
      } else {
        failStage(stage, of: worktree, failure)
      }
      return
    }
    guard runningHook else {
      endSetup(of: worktree, stopper: stopper)
      if let last = placements.last { finishStage(WorktreeOperation.Step(last), of: worktree) }
      return
    }
    if !placements.isEmpty { worktreeOperations.advance(to: .postCreateHook, on: worktree.id) }
    await runPostCreateHook(
      for: worktree, branch: branch, in: project, shellPath: shellPath, stopper: stopper)
  }

  /// Lets go of the task and its stop handle, whichever stage ended.
  private func endSetup(of worktree: Worktree, stopper: ProcessStopper) {
    worktreeSetups[worktree.id] = nil
    if stageStoppers[worktree.id] === stopper { stageStoppers[worktree.id] = nil }
    readBadges(of: worktree.id, in: worktree.projectID)
  }

  /// A path already listed is someone's row, and a doomed create must not
  /// blank it. Returns what was claimed, for `endConstruction`.
  func claimConstruction(of planned: URL) -> Worktree.ID? {
    let id = planned.standardizedFileURL.path
    guard workspace.worktree(id) == nil else { return nil }
    creatingWorktreeClaims[id, default: 0] += 1
    return id
  }

  /// One claim let go, not the path: another create may still hold it.
  /// A stage that has begun reads when it ends instead.
  func endConstruction(of id: Worktree.ID, in project: Project) {
    if let count = creatingWorktreeClaims[id], count > 1 {
      creatingWorktreeClaims[id] = count - 1
    } else {
      creatingWorktreeClaims[id] = nil
    }
    if !worktreeOperations.isUnderWay(id) { readBadges(of: id, in: project.id) }
  }

  /// Nothing writes there now, so read rather than wait out the poll. Judged
  /// when the read runs: `endSetup` is called before a file list's entry clears.
  private func readBadges(of id: Worktree.ID, in projectID: Project.ID) {
    scheduleStatusRefresh(of: id)
    Task { @MainActor [weak self] in
      guard let self, !isUnderConstruction(id), let project = workspace.project(projectID)
      else { return }
      await refreshMergeStates(of: project)
    }
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
      report(error)
      return
    }
    let shownInPane = worktreeOperations.fail(
      step, on: worktree.id, message: PresentedError(error).message, timedOut: timedOut)
    if !shownInPane { report(error) }
  }

  /// One of the project's file lists, before the post-create hook. Returns
  /// what went wrong rather than throwing; off the main thread.
  private func placeListedFiles(
    _ placement: WorktreePlacement, into path: URL, for project: Project, stopper: ProcessStopper
  ) async -> (any Error)? {
    guard let worktrees else { return nil }
    return await Self.offMain {
      do {
        try worktrees.placeFiles(placement, for: project, into: path, stopper: stopper)
        return nil
      } catch {
        return error
      }
    }
  }

  private func runPostCreateHook(
    for worktree: Worktree, branch: String, in project: Project, shellPath: String?,
    stopper: ProcessStopper
  ) async {
    defer { endSetup(of: worktree, stopper: stopper) }
    do {
      try await worktrees?.runPostCreate(
        for: project, worktreePath: worktree.path, branch: branch, shellPath: shellPath,
        timeout: workspace.hookTimeout, stopper: stopper)
    } catch {
      let stop = (error as? HookFailure)?.stop
      // Stopped by the user: the worktree is theirs to use, as after a
      // finish. A stop for any other reason is the timeout.
      if stop == .stopped {
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
    openFirstOrNewTab(in: current, on: .onCreate)
    warmWorktrees.insert(current.id)
    // The keyboard moves into the new pane only where the user is looking at
    // it; anywhere else the shell starts and the keyboard stays put.
    reconcileSessions(takingFocus: !showsAgentBoard && workspace.selectedWorktreeID == current.id)
  }
}
