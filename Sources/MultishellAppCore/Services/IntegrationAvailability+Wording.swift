import MultishellCore
import MultishellServices

extension IntegrationAvailability {
  /// The Integrations page's line under an integration's toggle, naming the
  /// command that would fix what is wrong.
  public func text(of integration: ServiceIntegration) -> String {
    let tool = integration.executableName
    switch self {
    case .checking:
      return t("integrations.checking", tool)

    case .needsGit:
      return t("integrations.needs-git", tool)

    case .notInstalled:
      return t("integrations.not-installed", tool, tool)

    case .tool(.ready(version: let version, account: let account?)):
      return t("integrations.ready-as", tool, version, account)

    case .tool(.ready(version: let version, account: nil)):
      return t("integrations.ready", tool, version)

    case .tool(.loggedOut):
      return t("integrations.logged-out", tool, "\(tool) auth login")

    case .tool(.unsupportedVersion(let version)):
      return t("integrations.too-old", tool, version, tool)

    case .tool(.unreadable(let said)):
      return t("integrations.unreadable", tool, said)
    }
  }
}
