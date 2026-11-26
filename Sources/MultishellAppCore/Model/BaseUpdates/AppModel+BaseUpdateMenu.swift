import MultishellCore
import MultishellGitKit

extension AppModel {
  /// What the worktree's menu offers about its base, `nil` for nothing. A stop
  /// is read off the row's status, whoever's merge or rebase it is.
  public func baseUpdateMenu(for worktree: Worktree) -> BaseUpdateMenu? {
    let isRunning = baseUpdateSteps[worktree.id] != nil || isBusy(worktree.id)
    if let status = statuses[worktree.id], let method = status.unfinishedUpdate {
      let sendTargets = ConflictSendTargets(
        recipients: handoffRecipients(in: worktree.id),
        opensAgentTab: effectiveAgentID(for: worktree) != nil,
      )
      return .unfinished(
        method,
        sendTargets: status.conflicted > 0 ? sendTargets : nil,
        isRunning: isRunning,
      )
    }
    return updatableBase(of: worktree).map { .update(base: $0.shortName, isRunning: isRunning) }
  }
}
