import MultishellCore

extension PullRequestPage {
  /// `nil` where there is a pull request to show.
  public var emptyText: PanelPageEmptyText? {
    switch self {
    case .noPullRequest(let branch, let isPushed):
      PanelPageEmptyText(
        title: t("panel.no-pull-request", branch),
        detail: isPushed
          ? t("panel.no-pull-request-pushed", branch)
          : t("panel.no-pull-request-unpushed", branch),
      )

    case .notApplicable:
      PanelPageEmptyText(title: t("panel.pull-request-not-applicable"), detail: nil)

    case .notHosted: PanelPageEmptyText(title: t("panel.not-hosted"), detail: nil)

    case .notRead(let problem): PanelPageEmptyText(title: t("panel.not-read"), detail: problem)

    case .pullRequest: nil

    case .trunk: PanelPageEmptyText(title: t("panel.pull-request-trunk"), detail: nil)

    case .turnedOff:
      PanelPageEmptyText(
        title: t("panel.pull-requests-off"),
        detail: t("panel.turned-off-detail"),
      )
    }
  }
}
