import MultishellCore

/// Whose hooks and whether the command-line tool are installed, read on or
/// off the main actor and recorded on it by `AppModel.recordInstallState`.
struct IntegrationInstallState: Sendable {
  let installedHooks: Set<String>
  let staleHooks: Set<String>
  let isCommandLineToolInstalled: Bool

  static func read() -> IntegrationInstallState {
    let states = AgentHookCatalogue.integrations.map {
      (id: $0.id, state: $0.installState())
    }
    return IntegrationInstallState(
      installedHooks: Set(states.filter { $0.state != .absent }.map(\.id)),
      staleHooks: Set(states.filter { $0.state == .stale }.map(\.id)),
      isCommandLineToolInstalled: HelperLink.isCommandLineToolInstalled)
  }
}
