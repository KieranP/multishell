import MultishellCore

/// What the Integrations page says of each integration's toggle.
extension ServiceIntegration {
  public var settingsLabel: String {
    switch self {
    case .circleCI: t("integrations.circleci-label")
    case .gitHub: t("integrations.github-label")
    }
  }

  public var settingsInfo: String {
    switch self {
    case .circleCI: t("integrations.circleci-info")
    case .gitHub: t("integrations.github-info")
    }
  }
}
