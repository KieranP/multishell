import MultishellCore

extension PresentedError {
  /// What a service's tool, or the push before a new pull request, refused.
  static func serviceAlert(_ error: any Error) -> Alert? {
    switch error {
    case let failure as BranchPublishFailure:
      return (t("error.branch-not-pushed", failure.branch), describe(failure.underlying))

    case let failure as NoRemoteToPublishTo:
      return (t("error.branch-not-pushed", failure.branch), t("error.no-remote-to-push-to"))

    case let failure as RemotesUnknown:
      return (t("error.pull-request-not-started", failure.branch), t("error.remotes-unknown"))

    case let failure as UnpushedCommitsUnknown:
      return (
        t("error.pull-request-not-started", failure.branch), t("error.unpushed-commits-unknown"),
      )

    case let failure as ServiceOpenFailure:
      return (
        t("error.service-not-opened", failure.integration.displayName),
        describe(failure.underlying),
      )

    default:
      return nil
    }
  }
}
