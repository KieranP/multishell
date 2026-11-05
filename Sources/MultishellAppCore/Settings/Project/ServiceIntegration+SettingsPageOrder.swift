import MultishellCore

extension ServiceIntegration {
  /// The Integrations page's order: pull requests first, the more common.
  public static let settingsPageOrder: [Self] = [.gitHub, .circleCI]
}
