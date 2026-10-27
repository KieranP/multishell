import MultishellCore

extension CIPage {
  /// `nil` where there is a run to show.
  public var emptyText: PanelEmptyText? {
    switch self {
    case .noRuns(let branch): PanelEmptyText(title: t("panel.no-runs", branch), detail: nil)

    case .notApplicable: PanelEmptyText(title: t("panel.ci-not-applicable"), detail: nil)

    case .notConfigured: PanelEmptyText(title: t("panel.ci-not-configured"), detail: nil)

    case .notHosted(let provider):
      PanelEmptyText(title: t("services.not-hosted", provider), detail: nil)

    case .notPushed(let branch):
      PanelEmptyText(title: t("panel.no-runs", branch), detail: t("panel.not-pushed"))

    case .notRead(let problem): PanelEmptyText(title: t("panel.not-read"), detail: problem)

    case .run: nil

    case .turnedOff: PanelEmptyText(title: t("panel.ci-off"), detail: t("panel.turned-off-detail"))
    }
  }
}
