import MultishellCore

extension ControlSettingsPage {
  // One case a word, exhaustive; settings.md says why not raw values.
  // swiftlint:disable cyclomatic_complexity
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
