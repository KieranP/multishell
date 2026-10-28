import MultishellServices

/// What the Integrations page says of an integration's tool.
public enum IntegrationAvailability: Equatable, Sendable {
  /// Being asked, the page having just opened.
  case checking
  /// Installed, but nothing is read without git, which finds the repository.
  case needsGit
  case notInstalled
  case tool(ServiceToolStatus)
}
