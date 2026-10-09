import Foundation
import MultishellCore
import MultishellGitKit
import MultishellProcess

extension AppModel {
  func plannedPath(
    forBranch branch: String,
    createsBranch: Bool,
    in project: Project,
  )
    -> URL?
  {
    coordinator?.plannedPath(
      forBranch: branch,
      in: project,
      settings: effectiveWorktreeSettings(for: project),
      createsBranch: createsBranch,
    )
  }

  /// The sheet's Cancel while the pre-create hook or git runs. A stopped
  /// add takes back the branch and directories it made; see worktrees.md.
  public func cancelWorktreeCreation() {
    stageHandles.stopCreation()
  }

  /// A step reported by the create `stopper` belongs to, and dropped once
  /// that create has ended: a late one would silence the shared-hooks question.
  func noteCreationStep(_ step: WorktreeCreationStep, of stopper: ProcessStopper) {
    guard stageHandles.isCurrentCreation(stopper) else { return }
    worktreeCreationStep = step
  }

  /// Returns once the worktree exists and is selected, or the create failed; the
  /// hook runs on in the pane. `firstTab` nil leaves the tab to the create settings.
  public func createWorktree(
    branch: String,
    basedOn startPoint: String?,
    createsBranch: Bool,
    in project: Project,
    firstTab: NewWorktreeFirstTab? = nil,
  ) async {
    // The workspace, not the value handed in: a sheet held open across a
    // removal would add a worktree nothing in the app lists.
    guard let coordinator, workspace.project(project.id) != nil else { return }
    // A branch can add the symlink without moving the file's bytes, so the
    // verdict cached at the read is asked of the disk again; see settings.md.
    let project = await reconfineSharedSettings(of: project)
    guard workspace.project(project.id) != nil else { return }
    let effective = effectiveProject(project)
    let settings = effectiveWorktreeSettings(for: project)
    let shell = workspace.effectiveShellPath(for: effective)
    // The row can arrive mid-checkout: git writes its record before the
    // first file, and that directory is watched. See worktrees.md.
    let claimed = plannedPath(forBranch: branch, createsBranch: createsBranch, in: project)
      .flatMap(claimPath(_:))
    let stopper = ProcessStopper()
    stageHandles.beginCreation(with: stopper)
    defer {
      if stageHandles.isCurrentCreation(stopper) { worktreeCreationStep = nil }
      stageHandles.endCreation(with: stopper)
      if let claimed { releasePathClaim(claimed, in: project) }
    }
    let path: URL
    do {
      path = try await coordinator.create(
        branch: branch,
        in: effective,
        settings: settings,
        basedOn: startPoint,
        createsBranch: createsBranch,
        shellPath: shell,
        timeout: workspace.projectHookTimeout,
        stopper: stopper,
        onStep: { [weak self] step in
          Task { @MainActor in self?.noteCreationStep(step, of: stopper) }
        },
      )
    } catch {
      reportUnlessStopped(error)
      return
    }
    await refreshWorktrees(of: project)
    await rearmWatcher()
    let name = WorktreeCoordinator.qualifiedBranchName(
      branch,
      createsBranch: createsBranch,
      settings: settings,
    )
    guard let created = createdWorktree(at: path, branchName: name, in: project) else { return }
    if let firstTab { newWorktreeFirstTabs[created.id] = firstTab }
    beginWorktreeSetup(
      of: created,
      branch: name,
      in: effective,
      shellPath: shell,
      lists: fileLists(of: project, inEffect: effective),
    )
    select(created, openingFirstTab: .onCreate)
    // A setup still running holds the tab back, and `openHeldBackTab` takes it.
    if !isBusy(created.id) { newWorktreeFirstTabs[created.id] = nil }
  }

  /// The user's Cancel, of the hook or of git itself, is nothing to report.
  private func reportUnlessStopped(_ error: any Error) {
    let stopReason =
      (error as? HookFailure)?.stopReason ?? (error as? ProcessFailure)?.stopReason
    if stopReason != .byUser { present(error) }
  }

  /// git reports resolved paths, so on a symlinked volume the directory we
  /// asked for and the one it lists can differ. Falls back to the branch.
  private func createdWorktree(at path: URL, branchName: String, in project: Project) -> Worktree? {
    workspace.worktree(path.standardizedFileURL.path)
      ?? workspace.worktrees(of: project.id).first(where: { $0.branch == branchName })
  }

  /// A path already listed is someone's row, and a doomed create must not
  /// blank it. Returns what was claimed, for `releasePathClaim`.
  func claimPath(_ planned: URL) -> Worktree.ID? {
    let id = planned.standardizedFileURL.path
    guard workspace.worktree(id) == nil else { return nil }
    pathClaims.claim(id)
    return id
  }

  /// One claim let go, not the path: another create may still hold it.
  /// A stage that has begun reads when it ends instead.
  func releasePathClaim(_ id: Worktree.ID, in project: Project) {
    pathClaims.release(id)
    if !worktreeOperations.isRunning(id) { refreshBadges(of: id, in: project.id) }
  }
}
