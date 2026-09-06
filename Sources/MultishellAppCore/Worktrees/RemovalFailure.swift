import MultishellGitKit

/// How a failed stage of a worktree removal is shown, decided apart from the
/// model so the four cases are tested.
///
/// A pre-delete veto leaves the worktree and its terminals in place, so the
/// pane says why until dismissed. Everything else is an alert: git's own
/// refusal keeps the worktree and offers the forced form; a post-delete
/// hook or a branch that would not go leaves the worktree gone and, when the
/// branch was to be deleted, says it was kept.
public enum RemovalFailure: Equatable, Sendable {
  public enum Retry: Equatable, Sendable {
    case removeAnyway
    case deleteBranchAnyway(String)
  }

  /// The worktree stays; the pane shows this until the user dismisses it.
  case vetoed(String)
  /// An alert. `worktreeRemoved` says whether the sidebar still has the
  /// worktree, which decides whether the model refreshes or restores it.
  case alert(title: String, message: String, retry: Retry?, worktreeRemoved: Bool)

  /// `branch` is the worktree's branch when the removal was to delete it,
  /// `nil` otherwise. `force` is whether git was already asked forcibly.
  public static func describe(
    _ error: any Error, deletingBranch branch: String?, force: Bool
  )
    -> RemovalFailure
  {
    switch error {
    case let failure as HookFailure where !failure.stage.operationHappened:
      return .vetoed(PresentedError(failure).message)
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
      // git refuses dirty or locked worktrees. Offer the force form rather
      // than leaving the user to find a terminal.
      let presented = PresentedError(error)
      return .alert(
        title: presented.title, message: presented.message,
        retry: force ? nil : .removeAnyway, worktreeRemoved: false)
    }
  }
}
