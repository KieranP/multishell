import Foundation
import MultishellCore
import MultishellGitKit
import MultishellProcess

// MARK: - Creating a worktree, and the post-create hook that outlives the sheet

extension AppModel {
  /// Opens the sheet for `project`, or for the project the workspace is
  /// working in when none is given: the selected worktree's, or the only one.
  /// With several projects and nothing selected the picker starts blank.
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

  /// The sheet's Cancel while the pre-create hook runs: nothing is created.
  public func cancelWorktreeCreation() {
    creationStopper?.stop()
  }

  /// Returns once the worktree exists and is selected, or the create
  /// failed. The post-create hook then runs on its own with the pane
  /// showing it, and holds the first tab back until it ends; see
  /// `WorktreeOperation`.
  public func createWorktree(
    branch: String,
    basedOn startPoint: String?,
    createBranch: Bool,
    in project: Project
  ) async {
    // The workspace and not the value handed in: a sheet held open across a
    // removal would otherwise run `git worktree add` for a project that has
    // gone, and `refresh` drops the result, leaving a directory on disk that
    // nothing in the app lists.
    guard let worktrees, workspace.project(project.id) != nil else { return }
    let stopper = ProcessStopper()
    creationStopper = stopper
    defer {
      worktreeCreationStep = nil
      creationStopper = nil
    }
    let resolved = resolved(project)
    let settings = worktreeSettings(for: project)
    let shell = workspace.defaultShell(for: project)
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
        onStep: { [weak self] step in Task { @MainActor in self?.worktreeCreationStep = step } }
      )
    } catch {
      // The user's Cancel: nothing to report, nothing was created.
      if (error as? HookFailure)?.stop != .stopped { report(error) }
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
    // build cache is not something to hold the window for, and the pane is
    // where a failure can still be read once the sheet has gone.
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
    select(created, openingFirstTab: .onCreate, byUser: false)
  }

  /// What a new worktree gets before its first terminal: the file lists a
  /// project has, in `placements` order, then the post-create hook, as one
  /// pane operation moving through its stages.
  ///
  /// A list that fails stops the stages after it, since a hook written to
  /// use the files it was promised turns one clear failure into a confusing
  /// second one. So does the user's Cancel, which is a decision to get on
  /// with the worktree rather than to run the rest of the setup.
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
      // The user's Cancel: the worktree is theirs to use, as after a
      // stopped hook, with what was placed before it left where it is.
      guard !(failure is WorktreeFilesStopped) else {
        if worktreeOperations.finish(stage, on: worktree.id) { openHeldBackTab(of: worktree) }
        return
      }
      let shownInPane =
        workspace.worktree(worktree.id) != nil
        && worktreeOperations.fail(
          stage, on: worktree.id, message: PresentedError(failure).message)
      if !shownInPane { report(failure) }
      return
    }
    guard runningHook else {
      endSetup(of: worktree, stopper: stopper)
      // A removal that began meanwhile owns the entry now.
      if let last = placements.last,
        worktreeOperations.finish(WorktreeOperation.Step(last), on: worktree.id)
      {
        openHeldBackTab(of: worktree)
      }
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
  }

  /// One of the project's file lists, before the post-create hook, so the
  /// hook and the first terminal both find the files. Returns what went
  /// wrong rather than throwing, since the stage it belongs to is the
  /// caller's. Off the main thread: a list may name a build cache.
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
      // finish. Anything else stays on the pane until dismissed, where the
      // worktree is still there to have a pane and the hook still owns it;
      // an alert otherwise.
      guard stop != .stopped else {
        if worktreeOperations.finish(.postCreateHook, on: worktree.id) {
          openHeldBackTab(of: worktree)
        }
        return
      }
      let shownInPane =
        workspace.worktree(worktree.id) != nil
        && worktreeOperations.fail(
          .postCreateHook, on: worktree.id, message: PresentedError(error).message,
          timedOut: stop != nil)
      if !shownInPane { report(error) }
      return
    }
    // A removal that began meanwhile owns the entry now.
    guard worktreeOperations.finish(.postCreateHook, on: worktree.id) else { return }
    openHeldBackTab(of: worktree)
  }

  /// The first tab was held back while the hook ran; it opens now if the
  /// worktree is still what the user is looking at, and if the create
  /// setting says a new worktree gets one, else on the next visit.
  func openHeldBackTab(of worktree: Worktree) {
    if workspace.selectedWorktreeID == worktree.id, let current = workspace.worktree(worktree.id) {
      select(current, openingFirstTab: .onCreate, byUser: false)
    }
  }
}
