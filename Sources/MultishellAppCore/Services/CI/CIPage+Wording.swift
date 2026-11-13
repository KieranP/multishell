import MultishellCore

extension CIPage {
  /// `nil` where there is a run to show.
  public var emptyText: PanelPageEmptyText? {
    switch self {
    case .noRuns(let branch): PanelPageEmptyText(title: t("panel.no-runs", branch), detail: nil)

    case .notApplicable: PanelPageEmptyText(title: t("panel.ci-not-applicable"), detail: nil)

    case .notConfigured: PanelPageEmptyText(title: t("panel.ci-not-configured"), detail: nil)

    case .notHosted(let provider):
      PanelPageEmptyText(title: t("services.not-hosted", provider), detail: nil)

    case .notPushed(let branch):
      PanelPageEmptyText(title: t("panel.no-runs", branch), detail: t("panel.not-pushed"))

    case .notRead(let problem): PanelPageEmptyText(title: t("panel.not-read"), detail: problem)

    case .run: nil

    case .turnedOff:
      PanelPageEmptyText(title: t("panel.ci-off"), detail: t("panel.turned-off-detail"))
    }
  }
}
