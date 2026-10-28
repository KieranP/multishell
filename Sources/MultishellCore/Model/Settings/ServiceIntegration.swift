/// A service read through its own command-line tool. The raw value is saved,
/// so add cases but never rename one; see Docs/design/services.md.
public enum ServiceIntegration: String, Codable, Hashable, Sendable, CaseIterable {
  case circleCI = "circleci"
  case gitHub = "github"

  /// The command-line tool every read goes through, looked up on the login
  /// shell's PATH.
  public var executableName: String {
    switch self {
    case .circleCI: "circleci"
    case .gitHub: "gh"
    }
  }

  public var displayName: String {
    switch self {
    case .circleCI: t("integration.circleci")
    case .gitHub: t("integration.github")
    }
  }
}
