import MultishellCore
import MultishellGitKit

extension AppModel {
  /// The menu's Abort Merge or Abort Rebase, asked first where an agent works there,
  /// as it may be resolving the conflicts the abort throws away.
  public func requestUpdateAbort(of worktree: Worktree, method: UpdateMethod) async {
    guard let git = coordinator?.git, mayStartBaseUpdate(worktree) else { return }
    guard await git.unfinishedUpdate(in: worktree.path) == method else {
      await refreshAfterBaseUpdate(of: worktree)
      return
    }
    let mark = await git.unfinishedUpdateMark(in: worktree.path)
    guard let agentName = workingAgentName(in: worktree.id) else {
      await runUpdateAbort(worktree, method: method, mark: mark, using: git)
      return
    }
    let worktreeName = await displayNameWhileUnfinished(of: worktree, using: git)
    guard !beepIfAQuestionWaits() else { return }
    pendingUpdateAbort = PendingUpdateAbort(
      worktree: worktree,
      worktreeName: worktreeName,
      method: method,
      mark: mark,
      workingAgentName: agentName,
    )
  }

  /// The alert's answer.
  @discardableResult
  public func answerUpdateAbort(
    _ pending: PendingUpdateAbort,
    confirmed: Bool,
  ) -> Task<Void, Never>? {
    guard pendingUpdateAbort == pending else { return nil }
    pendingUpdateAbort = nil
    guard confirmed, let git = coordinator?.git else { return nil }
    return Task {
      await runUpdateAbort(
        pending.worktree,
        method: pending.method,
        mark: pending.mark,
        using: git,
      )
    }
  }

  /// The stop read again, as the agent may have finished it, or begun another the
  /// user never agreed to abort, even one of the same kind, while the question stood.
  private func runUpdateAbort(
    _ worktree: Worktree,
    method: UpdateMethod,
    mark: String?,
    using git: WorktreeGit,
  ) async {
    guard mayStartBaseUpdate(worktree) else { return }
    setIfChanged(\.baseUpdateSteps[worktree.id], .aborting)
    defer { setIfChanged(\.baseUpdateSteps[worktree.id], nil) }
    let current = await git.unfinishedUpdate(in: worktree.path)
    let currentMark = await git.unfinishedUpdateMark(in: worktree.path)
    let isAskedStop = current == method && currentMark == mark
    if isAskedStop {
      do {
        try await git.abortUpdate(worktree, method: method)
      } catch {
        if workspace.worktree(worktree.id) != nil { present(error) }
      }
    }
    await refreshAfterBaseUpdate(of: worktree)
    // Named after the re-read: the stop that took its place may be on a branch again.
    if !isAskedStop, current != nil, let listed = workspace.worktree(worktree.id) {
      presentedError = .abortSkipped(on: await displayNameWhileUnfinished(of: listed, using: git))
    }
  }
}
