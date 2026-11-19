import MultishellCore

extension SettingsSection {
  // One case a word, exhaustive; settings.md says why not raw values.
  // swiftlint:disable cyclomatic_complexity
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
      case .shortcutsEdit: .shortcutsEdit
      case .shortcutsFile: .shortcutsFile
      case .shortcutsTerminal: .shortcutsTerminal
      case .shortcutsView: .shortcutsView
      case .terminal: .terminal
      case .worktrees: .worktrees
      }
  }
  // swiftlint:enable cyclomatic_complexity
}
