/// Whether the project's repository is one the integration can say anything
/// about, as far as the app has found out.
public enum IntegrationRepositoryFit: Equatable, Sendable {
  /// The CI provider's configuration file is in no checkout of it.
  case notConfigured
  /// The host said none of its remotes are the host's.
  case notHosted
  /// Not known to be either; nothing has said otherwise.
  case unknown
}
