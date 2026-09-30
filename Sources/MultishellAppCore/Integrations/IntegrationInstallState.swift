import MultishellCore

/// Whose hooks and whether the command-line tool are installed, read off
/// the main actor and recorded on it by `AppModel.recordInstallState`.
struct IntegrationInstallState: Sendable {
  let installedHooks: Set<String>
  let staleHooks: Set<String>
  let commandLineToolInstalled: Bool

  static func read() -> IntegrationInstallState {
    let installations = AgentHookCatalogue.integrations.map {
      (id: $0.id, installation: $0.installation())
    }
    return IntegrationInstallState(
      installedHooks: Set(installations.filter { $0.installation != .absent }.map(\.id)),
      staleHooks: Set(installations.filter { $0.installation == .stale }.map(\.id)),
      commandLineToolInstalled: HelperLink.isCommandLineToolInstalled)
  }
}
