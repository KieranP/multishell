import MultishellCore

extension PullRequestPage {
  /// `nil` where there is a pull request to show.
  public var emptyText: PanelEmptyText? {
    switch self {
    case .noPullRequest(let branch, let isPushed):
      PanelEmptyText(
        title: t("panel.no-pull-request", branch),
        detail: isPushed
          ? t("panel.no-pull-request-pushed", branch)
          : t("panel.no-pull-request-unpushed", branch),
      )

    case .notApplicable: PanelEmptyText(title: t("panel.pull-request-not-applicable"), detail: nil)

    case .notHosted: PanelEmptyText(title: t("panel.not-hosted"), detail: nil)

    case .notRead(let problem): PanelEmptyText(title: t("panel.not-read"), detail: problem)

    case .pullRequest: nil

    case .turnedOff:
      PanelEmptyText(title: t("panel.pull-requests-off"), detail: t("panel.turned-off-detail"))
    }
  }
}
