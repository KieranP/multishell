import MultishellCore

extension ControlSettingsPage {
  /// The command line's word for the section, which a refusal lists.
  init(_ section: SettingsSection) {
    self =
      switch section {
      case .agentHooks: .agentHooks
      case .agents: .agents
      case .agentSettings: .agentSettings
      case .appearance: .appearance
      case .general: .general
      case .hooksCreate: .hooksCreate
      case .hooksDelete: .hooksDelete
      case .hooksEnvironment: .hooksEnvironment
      case .integrations: .integrations
      case .notifications: .notifications
      case .terminal: .terminal
      case .worktrees: .worktrees
      }
  }
}
