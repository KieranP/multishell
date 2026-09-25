import MultishellCore

extension AppModel {
  /// Whose hooks and whether the command-line tool are installed. Six files,
  /// read here on the main actor: the settings rows ask after writing one.
  public func refreshInstallState() {
    recordInstallState(Self.installState())
  }

  nonisolated static func installState() -> IntegrationInstallState {
    let installations = AgentHookCatalogue.integrations.map { ($0.id, $0.installation()) }
    return IntegrationInstallState(
      hooks: Set(installations.filter { $0.1 != .absent }.map(\.0)),
      staleHooks: Set(installations.filter { $0.1 == .stale }.map(\.0)),
      commandLineToolInstalled: HelperLink.isCommandLineToolInstalled)
  }

  func recordInstallState(_ state: IntegrationInstallState) {
    setIfChanged(\.installedAgentHooks, state.hooks)
    setIfChanged(\.staleAgentHooks, state.staleHooks)
    setIfChanged(\.commandLineToolInstalled, state.commandLineToolInstalled)
  }

  /// The agents Settings > Agents offers hooks for: the ones this machine
  /// has, and any whose hooks are still installed.
  public var agentHooksRows: [AgentHooksRow] {
    AgentHooksRow.rows(
      detection: agentDetection, installed: installedAgentHooks, stale: staleAgentHooks)
  }

  /// The file as it would be written, for the row that shows it.
  public func agentHooksSnippet(_ id: String) -> String {
    AgentHookCatalogue.integration(for: id)?.snippet() ?? ""
  }

  public func installAgentHooks(_ id: String) {
    guard let integration = AgentHookCatalogue.integration(for: id) else { return }
    do {
      try integration.install()
    } catch {
      report(error)
    }
    refreshInstallState()
  }

  public func removeAgentHooks(_ id: String) {
    guard let integration = AgentHookCatalogue.integration(for: id) else { return }
    do {
      try integration.remove()
    } catch {
      report(error)
    }
    refreshInstallState()
  }

  public func installCommandLineTool() {
    do {
      try platform.installCommandLineTool()
    } catch {
      report(error)
    }
    refreshInstallState()
  }
}
