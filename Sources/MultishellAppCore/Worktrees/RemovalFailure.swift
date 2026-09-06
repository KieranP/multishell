import MultishellGitKit
import MultishellProcess

/// How a failed stage of a worktree removal is shown, decided apart from the
/// model so the cases are tested.
///
/// A pre-delete veto leaves the worktree and its terminals in place, so the
/// pane says why until dismissed; so does a pre-delete hook that ran past
/// the timeout. A pre-delete hook the user stopped is not a failure at all:
/// the worktree stays and nothing is said. Everything else is an alert: a
/// directory that could be neither trashed nor deleted, or git failing to
/// unlock or prune, keeps the worktree; a post-delete hook that failed, timed out or was stopped, or a
/// branch that would not go, leaves the worktree gone and, when the branch
/// was to be deleted, says it was kept.
public enum RemovalFailure: Equatable, Sendable {
  public enum Retry: Equatable, Sendable {
    case deleteBranchAnyway(String)
  }

  /// The worktree stays; the pane shows this until the user dismisses it.
  case vetoed(message: String, timedOut: Bool)
  /// The user stopped the pre-delete hook. The worktree stays, quietly.
  case stopped
  /// An alert. `worktreeRemoved` says whether the sidebar still has the
  /// worktree, which decides whether the model refreshes or restores it.
  case alert(title: String, message: String, retry: Retry?, worktreeRemoved: Bool)

  /// `branch` is the worktree's branch when the removal was to delete it,
  /// `nil` otherwise.
  public static func describe(
    _ error: any Error, deletingBranch branch: String?
  )
    -> RemovalFailure
  {
    switch error {
    case let failure as HookFailure
    where !failure.stage.operationHappened && failure.stop == .stopped:
      return .stopped
    case let failure as HookFailure where !failure.stage.operationHappened:
      return .vetoed(message: PresentedError(failure).message, timedOut: failure.stop != nil)
    case let failure as HookFailure:
      // The branch is deleted after the post hook, so a hook that failed
      // kept it; the alert has to say so, or the user believes it went.
      let presented = PresentedError(failure)
      let kept = branch.map { "\n\nThe branch \($0) was kept." } ?? ""
      return .alert(
        title: presented.title, message: presented.message + kept, retry: nil,
        worktreeRemoved: true)
    case let failure as BranchDeletionFailure:
      // The worktree is gone; only the branch stayed, because it has
      // commits nothing else has. Offer the forced form.
      let presented = PresentedError(failure)
      return .alert(
        title: presented.title, message: presented.message,
        retry: .deleteBranchAnyway(failure.branch), worktreeRemoved: true)
    default:
      // The Trash refused, or git could not unlock or prune. Nothing moved
      // or was pruned, so the worktree and its terminals come back.
      let presented = PresentedError(error)
      return .alert(
        title: presented.title, message: presented.message, retry: nil, worktreeRemoved: false)
    }
  }
}
