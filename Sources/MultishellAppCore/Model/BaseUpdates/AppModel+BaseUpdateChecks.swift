import MultishellCore
import MultishellGitKit

/// What refuses, or asks about, a merge or rebase from the base, read afresh each
/// time: before the question, and again after the fetch.
extension AppModel {
  /// Nothing about the base under way there, and no create or removal.
  func mayStartBaseUpdate(_ worktree: Worktree) -> Bool {
    baseUpdateSteps[worktree.id] == nil && !isBusy(worktree.id)
  }

  /// The refusal, else the reasons to ask, read with the row marked as checking, so
  /// Remove and a second click wait for it.
  func checkBaseUpdate(
    _ worktree: Worktree,
    by method: UpdateMethod,
    onto base: DefaultBranch,
    using git: WorktreeGit,
  ) async -> Result<PendingBaseUpdate, BaseUpdateRefusal> {
    setIfChanged(\.baseUpdateSteps[worktree.id], .checking)
    defer { setIfChanged(\.baseUpdateSteps[worktree.id], nil) }
    if let refusal = await baseUpdateRefusal(worktree, onto: base, using: git) {
      return .failure(refusal)
    }
    return .success(await baseUpdateQuestion(worktree, by: method, onto: base, using: git))
  }

  /// A stop is read first: it detaches a rebase's branch, which would read as moved.
  func baseUpdateRefusal(
    _ worktree: Worktree,
    onto base: DefaultBranch,
    using git: WorktreeGit,
  ) async -> BaseUpdateRefusal? {
    if let method = await git.unfinishedUpdate(in: worktree.path) {
      return .unfinishedUpdate(method)
    }
    if await git.isPickingCommits(in: worktree.path) { return .pickingCommits }
    do {
      let changes = try await git.uncommittedChanges(in: worktree)
      if !changes.isEmpty { return .uncommittedChanges(changes) }
    } catch {
      return workspace.worktree(worktree.id) == nil ? .gone : .unreadable(error)
    }
    return await movedBranchRefusal(of: worktree, onto: base)
  }

  /// The reasons to ask, as they stand now.
  func baseUpdateQuestion(
    _ worktree: Worktree,
    by method: UpdateMethod,
    onto base: DefaultBranch,
    using git: WorktreeGit,
  ) async -> PendingBaseUpdate {
    let rewrites = method == .rebase ? await git.isPushed(worktree) : false
    return PendingBaseUpdate(
      worktree: worktree,
      method: method,
      base: base,
      workingAgentName: workingAgentName(in: worktree.id),
      rewritesPushedBranch: rewrites,
    )
  }

  /// The refusal's alert. A stop the row had not read is read too, bringing its menu.
  func present(
    _ refusal: BaseUpdateRefusal,
    of worktree: Worktree,
    by method: UpdateMethod,
    onto base: DefaultBranch,
  ) async {
    switch refusal {
    case .gone: return

    case .unfinishedUpdate(let stopped):
      presentedError = .unfinishedUpdate(stopped, on: worktree.name)
      await refreshStatus(of: worktree.id, forced: true)

    case .uncommittedChanges(let changes):
      presentedError = .uncommittedChanges(
        on: worktree.name,
        method: method,
        base: base,
        changes: changes,
      )

    case .pickingCommits: presentedError = .pickingCommits(on: worktree.name)
    case .branchMoved(let current): presentedError = .branchMoved(from: worktree.name, to: current)
    case .baseChanged(let current): presentedError = .baseChanged(of: worktree.name, to: current)
    case .unreadable(let error): present(error)
    }
  }

  /// The first working agent's name there, for the question.
  func workingAgentName(in worktreeID: Worktree.ID) -> String? {
    for session in workspace.sessions(in: worktreeID) where isAgentWorking(in: session.id) {
      return agentIDAtThePrompt(of: session).map(agentDisplayName) ?? t("base-update.an-agent")
    }
    return nil
  }

  /// The branch or base `worktree` was read with, against git's list now.
  private func movedBranchRefusal(
    of worktree: Worktree,
    onto base: DefaultBranch,
  ) async -> BaseUpdateRefusal? {
    if let project = workspace.project(worktree.projectID) { await refreshWorktrees(of: project) }
    guard let current = workspace.worktree(worktree.id) else { return .gone }
    guard current.branch == worktree.branch else { return .branchMoved(to: current.name) }
    let currentBase = updatableBase(of: current)?.shortName
    guard currentBase == base.shortName else { return .baseChanged(to: currentBase) }
    return nil
  }
}
