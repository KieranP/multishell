/// What a service's command-line tool says about itself, for the
/// Integrations page: asked when the page opens, never on the poll.
public enum ServiceToolStatus: Hashable, Sendable {
  case loggedOut
  case ready(version: String, account: String?)
  /// It answered in a way this build cannot read, said as it said it.
  case unreadable(String)
  /// Older than the commands this build runs, by the version it gave.
  case unsupportedVersion(String)
}
