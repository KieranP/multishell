import MultishellCore
import MultishellGitKit
import MultishellProcess

/// How a failed stage of a worktree removal is shown: a pre-delete veto in
/// the pane, a stop silently, everything else an alert.
enum RemovalFailure: Equatable, Sendable {
  enum ForcedRetry: Equatable, Sendable {
    /// `git branch -D` on a branch `-d` refused. The alert's title already
    /// names the branch, so the button says only what it does.
    case deleteBranchAnyway(String)

    var label: String {
      switch self {
      case .deleteBranchAnyway: t("removal.force-deletion")
      }
    }
  }

  /// The worktree stays; the pane shows this until the user dismisses it.
  case vetoed(message: String, timedOut: Bool)
  /// The user stopped the pre-delete hook. The worktree stays, quietly.
  case stopped
  /// An alert. `worktreeRemoved` says whether the sidebar still has the
  /// worktree, which decides whether the model refreshes or restores it.
  case alert(title: String, message: String, retry: ForcedRetry?, worktreeRemoved: Bool)

  /// `branch` is the worktree's branch when the removal was to delete it,
  /// `nil` otherwise.
  init(_ error: any Error, deletingBranch branch: String?) {
    switch error {
    case let failure as HookFailure
    where !failure.stage.operationHappened && failure.stop == .byUser:
      self = .stopped
    case let failure as HookFailure where !failure.stage.operationHappened:
      self = .vetoed(message: PresentedError(failure).message, timedOut: failure.stop != nil)
    case let failure as HookFailure:
      // The branch is deleted after the post hook, so a hook that failed
      // kept it; the alert has to say so, or the user believes it went.
      let kept = branch.map { "\n\n" + t("removal.branch-was-kept", $0) } ?? ""
      self = .presenting(failure, adding: kept, worktreeRemoved: true)
    case let failure as NotTheCheckout:
      // Nothing was removed and nothing is worth retrying until it moves.
      self = .presenting(failure, worktreeRemoved: false)
    case let failure as WorktreeForgetFailure:
      // The directory is in the Trash, so there is nothing to restore; the
      // refresh shows the record git kept, directory missing.
      self = .presenting(failure, worktreeRemoved: true)
    case let failure as BranchDeletionFailure:
      // The worktree is gone; only the branch stayed, because it has
      // commits nothing else has. Offer the forced form.
      self = .presenting(
        failure, retry: .deleteBranchAnyway(failure.branch), worktreeRemoved: true)
    default:
      // The Trash refused, so nothing moved and the worktree and its
      // terminals come back.
      self = .presenting(error, worktreeRemoved: false)
    }
  }

  private static func presenting(
    _ error: any Error, adding extra: String = "", retry: ForcedRetry? = nil, worktreeRemoved: Bool
  ) -> RemovalFailure {
    let presented = PresentedError(error)
    return .alert(
      title: presented.title, message: presented.message + extra, retry: retry,
      worktreeRemoved: worktreeRemoved)
  }
}
