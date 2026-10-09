import Foundation
import MultishellCore
import MultishellGitKit

extension PresentedError {
  /// What git or the Trash refused about a worktree or a branch.
  static func worktreeAlert(_ error: any Error) -> Alert? {
    switch error {
    case let failure as BranchDeletionFailure:
      return (t("error.branch-not-deleted", failure.branch), describe(failure.underlying))

    case let failure as TrashFailure:
      return (t("error.trash-refused"), pathAndCause(failure.path, failure.underlying))

    case let failure as WorktreeRecordRemovalFailure:
      return (t("error.forget-refused"), pathAndCause(failure.path, failure.underlying))

    case let failure as WorktreePathTaken:
      return (
        t("error.not-the-checkout-title"), t("error.not-the-checkout-message", failure.path.path),
      )

    case let invalid as InvalidBranchName:
      return (t("error.invalid-branch-title"), invalid.errorDescription ?? "")

    case let notRemovable as WorktreeNotRemovable:
      return (t("error.not-a-worktree-title"), notRemovable.errorDescription ?? "")

    case is GitUnavailable:
      return (t("error.git-not-found-title"), t("error.git-not-found-message"))

    default:
      return nil
    }
  }

  private static func pathAndCause(_ path: URL, _ underlying: any Error) -> String {
    "\(path.path)\n\n\(describe(underlying))"
  }
}
