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
    guard let worktrees else { return }
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
    if WorktreeHooks.hasScript(resolved.settings.postCreateHook) {
      worktreeOperations.begin(.postCreateHook, on: created.id)
      // Made here, not in the task: a Stop Hook clicked before the task has
      // run would otherwise find nothing to stop.
      let stopper = ProcessStopper()
      hookStoppers[created.id] = stopper
      postCreateHooks[created.id] = Task {
        await runPostCreateHook(
          for: created, branch: name, in: resolved, shellPath: shell, stopper: stopper)
      }
    }
    select(created, openingFirstTab: .onCreate, byUser: false)
  }

  private func runPostCreateHook(
    for worktree: Worktree, branch: String, in project: Project, shellPath: String?,
    stopper: ProcessStopper
  ) async {
    defer {
      postCreateHooks[worktree.id] = nil
      if hookStoppers[worktree.id] === stopper { hookStoppers[worktree.id] = nil }
    }
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
