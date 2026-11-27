import MultishellCore

extension PresentedError {
  /// What a service's tool, or the push before a new pull request, refused.
  static func serviceAlert(_ error: any Error) -> Alert? {
    switch error {
    case let failure as BranchPublishFailure:
      return (t("error.branch-not-pushed", failure.branch), describe(failure.underlying))

    case let failure as PullRequestMergeFailure:
      let number = String(failure.number)
      let title =
        switch failure.action {
        case .merge: t("error.pull-request-not-merged", number)
        case .mergeWhenReady: t("error.auto-merge-not-turned-on", number)
        case .cancelAutoMerge: t("error.auto-merge-not-cancelled", number)
        }
      return (title, describe(failure.underlying))

    case let failure as ServiceOpenFailure:
      return (
        t("error.service-not-opened", failure.integration.displayName),
        describe(failure.underlying),
      )

    default:
      return nil
    }
  }

  /// Create Pull Request on a repository with no remote to push the branch to.
  static func noRemoteToPublishTo(_ branch: String) -> PresentedError {
    PresentedError(
      title: t("error.branch-not-pushed", branch),
      message: t("error.no-remote-to-push-to"),
    )
  }

  /// Create Pull Request where git could not list the remotes to push the branch to.
  static func remotesUnknown(_ branch: String) -> PresentedError {
    PresentedError(
      title: t("error.pull-request-not-started", branch),
      message: t("error.remotes-unknown"),
    )
  }

  /// Create Pull Request where git could not count the commits the remote lacks.
  static func unpushedCommitsUnknown(_ branch: String) -> PresentedError {
    PresentedError(
      title: t("error.pull-request-not-started", branch),
      message: t("error.unpushed-commits-unknown"),
    )
  }
}
