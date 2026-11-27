import MultishellCore
import MultishellGitKit

extension AppModel {
  private static func entry(of run: BaseUpdateRun) -> WorktreeUpdateEntry {
    switch run.outcome {
    case .updated:
      WorktreeUpdateEntry(outcome: .updated, conflicts: [], pane: nil)

    case .unfinished(let paths):
      WorktreeUpdateEntry(outcome: .conflicts, conflicts: paths, pane: run.conflictPane)
    }
  }

  /// The reason the flags did not go past: a working agent, else a pushed branch.
  private static func refusal(
    asking question: PendingBaseUpdate,
    past consent: BaseUpdateConsent,
    id: String,
  ) -> ControlRefusal {
    question.workingAgentName != nil && !consent.overWorkingAgent
      ? .agentWorking : .rewritesPushedBranch(id: id)
  }

  /// The record read again where it is detached: a rebase that just ended leaves it
  /// so until the next list read, which would refuse the update as having no base.
  private func relistedIfDetached(_ worktree: Worktree) async -> Worktree? {
    guard worktree.isDetached else { return worktree }
    await refreshAfterBaseUpdate(of: worktree)
    return workspace.worktree(worktree.id)
  }

  /// Merge from Base or Rebase onto Base without the question: what it would ask
  /// about is refused unless the order's flags go past it.
  func replyToUpdateWorktree(_ order: WorktreeUpdateOrder) async -> ControlReply {
    let id = order.worktreeID
    guard let stored = worktree(withControlID: id) else { return .refused(.noWorktree(id: id)) }
    guard let git = coordinator?.git else { return .refused(.gitNotFound) }
    guard let worktree = await relistedIfDetached(stored) else {
      return .refused(.noWorktree(id: id))
    }
    guard !isBusy(worktree.id) else { return .refused(.worktreeNotReady(id: id)) }
    guard baseUpdateSteps[worktree.id] == nil else { return .refused(.updateUnderWay(id: id)) }
    guard let base = updatableBase(of: worktree) else {
      // A stopped rebase detaches the branch, which offers no base, so it is named.
      if let method = await git.unfinishedUpdate(in: worktree.path) {
        return .refused(.unfinishedUpdate(id: id, method: method))
      }
      return .refused(.baseUpdateUnavailable(id: id))
    }
    let consent = BaseUpdateConsent(
      overWorkingAgent: order.force,
      rewritingPushedBranch: order.allowsRewritingPushedBranch,
    )
    // Asked before the fetch too, so a refusal costs no network.
    switch await checkBaseUpdate(worktree, by: order.method, onto: base, using: git) {
    case .failure(let refusal):
      return await reply(refusing: refusal, of: worktree, by: order.method, onto: base, id: id)

    case .success(let question) where question.exceeds(consent):
      return .refused(Self.refusal(asking: question, past: consent, id: id))

    case .success: break
    }
    switch await runBaseUpdate(worktree, by: order.method, onto: base, consenting: consent) {
    case .ran(let run): return .json(Self.entry(of: run))

    case .refused(let refusal):
      return await reply(refusing: refusal, of: worktree, by: order.method, onto: base, id: id)

    case .asks(let question):
      return .refused(Self.refusal(asking: question, past: consent, id: id))

    case .notStarted:
      return .refused(isBusy(worktree.id) ? .worktreeNotReady(id: id) : .updateUnderWay(id: id))

    case .cancelled, .failed:
      // A failure's alert was presented in this task, which makes it the answer.
      let isGone = workspace.worktree(worktree.id) == nil
      return .refused(isGone ? .noWorktree(id: id) : .worktreeNotReady(id: id))
    }
  }

  /// A refusal a script can read as data, else the menu's alert as the answer.
  private func reply(
    refusing refusal: BaseUpdateRefusal,
    of worktree: Worktree,
    by method: UpdateMethod,
    onto base: DefaultBranch,
    id: String,
  ) async -> ControlReply {
    switch refusal {
    case .gone: return .refused(.noWorktree(id: id))
    case .pickingCommits: return .refused(.pickingCommits(id: id))

    case .uncommittedChanges(let changes):
      return .refused(.uncommittedChanges(id: id, changes: changes))

    case .unfinishedUpdate(let method): return .refused(.unfinishedUpdate(id: id, method: method))

    case .baseChanged, .branchMoved, .unreadable:
      await present(refusal, of: worktree, by: method, onto: base)
      return .refused(.worktreeNotReady(id: id))
    }
  }
}
