/// Why a read through a service's tool gave no answer. Never a verdict: the
/// row keeps what it last showed; see Docs/design/services.md.
public enum ServiceReadFailure: Error, Hashable, Sendable {
  /// The tool ran and failed, with what it said.
  case failed(String)
  case loggedOut
  /// The repository is not on this service, so it is not asked again until
  /// its remotes change or ten minutes pass.
  case notHosted
}
