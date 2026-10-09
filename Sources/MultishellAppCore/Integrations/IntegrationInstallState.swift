import MultishellCore

/// Whose hooks and whether the command-line tool are installed, read on or
/// off the main actor and recorded on it by `AppModel.recordInstallState`.
struct IntegrationInstallState: Sendable {
  let installedHooks: Set<String>
  let staleHooks: Set<String>
  let isCommandLineToolInstalled: Bool

  static func read() -> Self {
    let states = AgentHookCatalogue.integrations.map { integration in
      (id: integration.id, state: integration.installState())
    }
    return Self(
      installedHooks: Set(states.filter { $0.state != .absent }.map(\.id)),
      staleHooks: Set(states.filter { $0.state == .stale }.map(\.id)),
      isCommandLineToolInstalled: HelperLink.isCommandLineToolInstalled,
    )
  }
}
