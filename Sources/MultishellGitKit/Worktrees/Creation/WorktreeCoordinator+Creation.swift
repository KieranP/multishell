import Foundation
import MultishellCore
import MultishellProcess

extension WorktreeCoordinator {
  /// Where `create` would put a worktree for this branch, so the sheet can
  /// show it first. `settings` is the project's effective value.
  public func plannedPath(
    forBranch rawBranch: String, createsBranch: Bool = true, in project: Project,
    settings: WorktreeSettings
  ) -> URL {
    settings.worktreePath(
      forBranch: Self.qualifiedBranchName(
        rawBranch, createsBranch: createsBranch, settings: settings),
      in: project)
  }

  /// The prefix names branches this app creates. An existing branch has its
  /// name already, and prefixing it would ask git for one that is not there.
  public static func qualifiedBranchName(
    _ raw: String, createsBranch: Bool, settings: WorktreeSettings
  ) -> String {
    createsBranch
      ? settings.qualifiedBranch(raw) : raw.trimmingCharacters(in: .whitespaces)
  }

  /// The pre-create hook and `git worktree add`, `runPostCreateHook` being
  /// separate so a slow hook does not hold the sheet. See hooks.md.
  @discardableResult
  public func create(
    branch rawBranch: String,
    basedOn startPoint: String? = nil,
    createsBranch: Bool = true,
    in project: Project,
    settings: WorktreeSettings,
    shellPath: String? = nil,
    timeout: Duration? = nil,
    stopper: ProcessStopper? = nil,
    onStep: (@Sendable (WorktreeCreationStep) -> Void)? = nil
  ) async throws -> URL {
    let branch = Self.qualifiedBranchName(
      rawBranch, createsBranch: createsBranch, settings: settings)
    // Before the hook, for an existing branch too: git rejects the name at
    // the end of it, and the hook's work is done by then.
    guard GitBranchName.isValid(branch) else { throw InvalidBranchName(branch) }
    // The one place the path is derived, so what the sheet showed and what
    // the model holds back from `git status` cannot part from what is made.
    let path = plannedPath(
      forBranch: rawBranch, createsBranch: createsBranch, in: project, settings: settings)

    try await WorktreeHooks.run(
      .preCreate, for: project, worktreePath: path, branch: branch, shellPath: shellPath,
      timeout: timeout, stopper: stopper, onWillRun: { onStep?(.preCreateHook) })
    onStep?(.addingWorktree)
    let undo = await stoppedAddUndo(
      at: path, branch: branch, createsBranch: createsBranch, in: project)
    do {
      try await git.add(
        branch: branch,
        at: path,
        basedOn: startPoint,
        createsBranch: createsBranch,
        in: project,
        stopper: stopper
      )
      await git.settleIndex(of: path, stopper: stopper)
      // A Cancel during that wait comes after git finished; see worktrees.md.
      if stopper?.isStopRequested == true {
        throw ProcessFailure.unreportedByGit(
          ["worktree", "add"], message: "stopped while the new index settled", stopReason: .byUser)
      }
    } catch  where stopper?.isStopRequested == true {
      await undoStoppedAdd(undo, in: project)
      throw error
    }
    return path
  }

  /// The other half of a create. Returns at once when the hook is blank.
  public func runPostCreateHook(
    for project: Project, worktreePath: URL, branch: String, shellPath: String? = nil,
    timeout: Duration? = nil, stopper: ProcessStopper? = nil
  ) async throws {
    try await WorktreeHooks.run(
      .postCreate, for: project, worktreePath: worktreePath, branch: branch, shellPath: shellPath,
      timeout: timeout, stopper: stopper)
  }
}
