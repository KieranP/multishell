import MultishellCore

extension IntegrationRepositoryFit {
  /// The Integrations page's line on why nothing is read; `nil` where nothing
  /// says so.
  public func text(of integration: ServiceIntegration) -> String? {
    switch self {
    case .notConfigured: t("integrations.not-configured", integration.displayName)
    case .notHosted: t("integrations.not-hosted", integration.displayName)
    case .unknown: nil
    }
  }
}
