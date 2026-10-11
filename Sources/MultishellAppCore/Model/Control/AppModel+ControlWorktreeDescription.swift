import Foundation
import MultishellCore
import MultishellGitKit

extension AppModel {
  /// Its row's status and badge and any stage under way, beside its list line.
  /// Git is read first: the poll pauses while the app is in the background.
  func replyToDescribeWorktree(_ id: String) async -> ControlReply {
    guard let asked = worktree(withControlID: id) else { return .refused(.noWorktree(id: id)) }
    let isStatusFresh = await refreshStatus(of: asked.id, forced: true)
    guard let worktree = workspace.worktree(asked.id) else { return .refused(.noWorktree(id: id)) }
    let (merge, mergedInto): (String, String?) =
      switch mergeState(of: worktree) {
      case .merged(_, let into): ("merged", into)
      case .unmerged: ("unmerged", nil)
      case .unknown: ("unknown", nil)
      }
    return .json(
      WorktreeDescription(
        entry: worktreeEntry(worktree, sessions: sessionIDsByWorktree),
        status: statuses[worktree.id].map { status in
          WorktreeDescription.Status(
            branch: status.branch,
            changedFiles: status.changedFiles,
            insertions: status.insertions,
            deletions: status.deletions,
            unscoredFiles: status.unscoredFiles,
            ahead: status.ahead,
            behind: status.behind,
            summary: status.summary,
          )
        },
        isStatusFresh: isStatusFresh,
        merge: merge,
        mergedInto: mergedInto,
        lastCommit: lastCommitDates[worktree.id],
        operation: worktreeOperations[worktree.id].map { operation in
          WorktreeDescription.Operation(
            stage: operation.stage.rawValue,
            isRunning: operation.isRunning,
            failure: operation.failure,
            didTimeOut: operation.didTimeOut,
          )
        },
      )
    )
  }
}
