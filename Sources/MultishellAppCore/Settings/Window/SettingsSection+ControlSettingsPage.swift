import MultishellCore

extension SettingsSection {
  /// The section the command line's word names.
  init(_ page: ControlSettingsPage) {
    self =
      switch page {
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
