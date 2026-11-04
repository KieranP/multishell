import MultishellCore

extension PullRequestPage {
  /// `nil` where there is a pull request to show.
  public var emptyText: ServicePageEmptyText? {
    switch self {
    case .noPullRequest(let branch, let isPushed):
      ServicePageEmptyText(
        title: t("panel.no-pull-request", branch),
        detail: isPushed
          ? t("panel.no-pull-request-pushed", branch)
          : t("panel.no-pull-request-unpushed", branch),
      )

    case .notApplicable:
      ServicePageEmptyText(title: t("panel.pull-request-not-applicable"), detail: nil)

    case .notHosted: ServicePageEmptyText(title: t("panel.not-hosted"), detail: nil)

    case .notRead(let problem): ServicePageEmptyText(title: t("panel.not-read"), detail: problem)

    case .pullRequest: nil

    case .trunk: ServicePageEmptyText(title: t("panel.pull-request-trunk"), detail: nil)

    case .turnedOff:
      ServicePageEmptyText(
        title: t("panel.pull-requests-off"),
        detail: t("panel.turned-off-detail"),
      )
    }
  }
}
