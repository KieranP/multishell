import Foundation
import MultishellCore
import MultishellGitKit
import MultishellProcess

extension AppModel {
  /// Opens the sheet for `project`, or the one being worked in. With several
  /// projects and nothing selected the picker starts blank.
  public func requestNewWorktree(in project: Project? = nil) {
    newWorktreeRequest = NewWorktreeRequest(projectID: (project ?? projectInView)?.id)
  }

  func plannedPath(
    forBranch branch: String, createBranch: Bool, in project: Project
  )
    -> URL?
  {
    coordinator?.plannedPath(
      forBranch: branch, createBranch: createBranch, in: project,
      settings: worktreeSettings(for: project))
  }

  /// Where the sheet's draft would put its worktree, or a dash while there
  /// is no project or no name to place.
  public func plannedLocation(for draft: NewWorktreeDraft) -> String {
    let name = draft.trimmedBranch
    guard let project = draft.projectID.flatMap(workspace.project), !name.isEmpty,
      let url = plannedPath(forBranch: name, createBranch: draft.createBranch, in: project)
    else { return "\u{2014}" }
    return url.path.abbreviatingHomeDirectory()
  }

  /// The sheet's reads, `nil` once the task asking is cancelled: a project
  /// switch cancels it but not the call inside, so each step checks.
  public func newWorktreeBranches(of project: Project) async -> NewWorktreeBranches? {
    let hasCommits = await hasCommits(project)
    guard !Task.isCancelled else { return nil }
    let (local, remote) = await branches(of: project)
    guard !Task.isCancelled else { return nil }
    let current = await currentBranch(of: project)
    guard !Task.isCancelled else { return nil }
    return NewWorktreeBranches(
      hasCommits: hasCommits, localBranches: local, remoteBranches: remote,
      currentBranch: current)
  }

  private func hasCommits(_ project: Project) async -> Bool {
    await coordinator?.git.hasCommits(project) ?? false
  }

  private func branches(of project: Project) async -> (local: [String], remote: [String]) {
    (
      (try? await coordinator?.git.localBranches(project)) ?? [],
      (try? await coordinator?.git.remoteBranches(project)) ?? []
    )
  }

  private func currentBranch(of project: Project) async -> String {
    (try? await coordinator?.git.currentBranch(project)) ?? "HEAD"
  }

  /// The sheet's Cancel while the pre-create hook or git runs. A stopped
  /// add takes back the branch and directories it made; see worktrees.md.
  public func cancelWorktreeCreation() {
    stageHandles.cancelCreation()
  }

  /// A step reported by the create `stopper` belongs to, and dropped once
  /// that create has ended: a late one would silence the shared-hooks question.
  func noteCreationStep(_ step: WorktreeCreationStep, of stopper: ProcessStopper) {
    guard stageHandles.isCreating(with: stopper) else { return }
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
    guard let coordinator, workspace.project(project.id) != nil else { return }
    // A branch can add the symlink without moving the file's bytes, so the
    // verdict cached at the read is asked of the disk again; see settings.md.
    let project = await reconfineSharedSettings(of: project)
    guard workspace.project(project.id) != nil else { return }
    let resolved = withEffectiveSettings(project)
    let settings = worktreeSettings(for: project)
    let shell = workspace.effectiveShellPath(for: project)
    // The row can arrive mid-checkout: git writes its record before the
    // first file, and that directory is watched. See worktrees.md.
    let claimed = plannedPath(forBranch: branch, createBranch: createBranch, in: project)
      .flatMap(claimConstruction(of:))
    let stopper = ProcessStopper()
    stageHandles.beginCreation(with: stopper)
    defer {
      if stageHandles.isCreating(with: stopper) { worktreeCreationStep = nil }
      stageHandles.endCreation(with: stopper)
      if let claimed { releaseConstruction(of: claimed, in: project) }
    }
    let path: URL
    do {
      path = try await coordinator.add(
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
      reportUnlessStopped(error)
      return
    }
    await refresh(project)
    await rearmWatcher()
    let name = WorktreeCoordinator.qualifiedBranchName(
      branch, createBranch: createBranch, settings: settings)
    guard let created = createdWorktree(at: path, branchName: name, in: project) else { return }
    beginWorktreeSetup(
      of: created, branch: name, in: resolved, shellPath: shell,
      lists: fileLists(of: project, resolvedBy: resolved))
    select(created, openingFirstTab: .onCreate)
  }

  /// The user's Cancel, of the hook or of git itself, is nothing to report.
  private func reportUnlessStopped(_ error: any Error) {
    let stop = (error as? HookFailure)?.stop ?? (error as? ProcessFailure)?.stop
    if stop != .byUser { present(error) }
  }

  /// git reports resolved paths, so on a symlinked volume the directory we
  /// asked for and the one it lists can differ. Falls back to the branch.
  private func createdWorktree(at path: URL, branchName: String, in project: Project) -> Worktree? {
    workspace.worktree(path.standardizedFileURL.path)
      ?? workspace.worktrees(of: project.id).first(where: { $0.branch == branchName })
  }

  /// A path already listed is someone's row, and a doomed create must not
  /// blank it. Returns what was claimed, for `releaseConstruction`.
  func claimConstruction(of planned: URL) -> Worktree.ID? {
    let id = planned.standardizedFileURL.path
    guard workspace.worktree(id) == nil else { return nil }
    pathClaims.claim(id)
    return id
  }

  /// One claim let go, not the path: another create may still hold it.
  /// A stage that has begun reads when it ends instead.
  func releaseConstruction(of id: Worktree.ID, in project: Project) {
    pathClaims.release(id)
    if !worktreeOperations.isUnderWay(id) { refreshBadges(of: id, in: project.id) }
  }
}
