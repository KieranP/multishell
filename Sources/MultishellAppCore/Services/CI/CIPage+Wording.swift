import MultishellCore

extension CIPage {
  /// `nil` where there is a run to show.
  public var emptyText: ServicePageEmptyText? {
    switch self {
    case .noRuns(let branch): ServicePageEmptyText(title: t("panel.no-runs", branch), detail: nil)

    case .notApplicable: ServicePageEmptyText(title: t("panel.ci-not-applicable"), detail: nil)

    case .notConfigured: ServicePageEmptyText(title: t("panel.ci-not-configured"), detail: nil)

    case .notHosted(let provider):
      ServicePageEmptyText(title: t("services.not-hosted", provider), detail: nil)

    case .notPushed(let branch):
      ServicePageEmptyText(title: t("panel.no-runs", branch), detail: t("panel.not-pushed"))

    case .notRead(let problem): ServicePageEmptyText(title: t("panel.not-read"), detail: problem)

    case .run: nil

    case .turnedOff:
      ServicePageEmptyText(title: t("panel.ci-off"), detail: t("panel.turned-off-detail"))
    }
  }
}
