import MultishellCore

extension AppModel {
  /// The agents Settings > Agents offers hooks for: the ones this machine
  /// has, and any whose hooks are still installed.
  public var agentHooksRows: [AgentHooksRow] {
    AgentHooksRow.rows(
      detection: agentDetection,
      installed: installedAgentHooks,
      stale: staleAgentHooks,
    )
  }

  /// Settings > Agents' line for the tool: where it is, or that it is not.
  public var commandLineToolStatusText: String {
    isCommandLineToolInstalled ? t("agents.helper-installed") : t("agents.not-installed")
  }

  /// Whose hooks and whether the command-line tool are installed. Six files,
  /// read here on the main actor: the settings rows ask after writing one.
  public func refreshInstallState() {
    recordInstallState(IntegrationInstallState.read())
  }

  func recordInstallState(_ state: IntegrationInstallState) {
    setIfChanged(\.installedAgentHooks, state.installedHooks)
    setIfChanged(\.staleAgentHooks, state.staleHooks)
    setIfChanged(\.isCommandLineToolInstalled, state.isCommandLineToolInstalled)
  }

  /// The file as it would be written, for the row that shows it.
  public func agentHooksSnippet(_ id: String) -> String {
    AgentHookCatalogue.integration(id)?.snippet() ?? ""
  }

  public func installAgentHooks(_ id: String) {
    guard let integration = AgentHookCatalogue.integration(id) else { return }
    changeInstallState { try integration.install() }
  }

  public func removeAgentHooks(_ id: String) {
    guard let integration = AgentHookCatalogue.integration(id) else { return }
    changeInstallState { try integration.remove() }
  }

  public func installCommandLineTool() {
    changeInstallState { try platform.installCommandLineTool() }
  }

  private func changeInstallState(_ change: () throws -> Void) {
    presentingFailure(change)
    refreshInstallState()
  }
}
