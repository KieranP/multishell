/// A page in the settings window's sidebar. Some pages exist in one scope
/// only, and a page too tall for the window lists its parts beneath it.
public enum SettingsPage: Hashable, Sendable {
  case actions
  case agents
  case appearance
  case general
  case hooks
  case integrations
  case notifications
  case shortcuts
  case terminal
  case worktrees

  private static let allProjectsOrder: [Self] = [
    .general, .worktrees, .terminal, .agents, .notifications, .appearance, .shortcuts,
  ]
  private static let projectOrder: [Self] = [
    .general, .worktrees, .hooks, .terminal, .agents, .actions, .integrations,
  ]

  /// The sidebar's pages for `scope`, in the order it lists them.
  static func pages(in scope: SettingsScope) -> [Self] {
    scope == .allProjects ? allProjectsOrder : projectOrder
  }

  /// What selecting the page can show in `scope`: one section, its parts, or
  /// none where the scope has no such page.
  public func sections(in scope: SettingsScope) -> [SettingsSection] {
    let isAllProjects = scope == .allProjects
    return switch self {
    case .actions: isAllProjects ? [] : [.actions]
    case .agents: isAllProjects ? [.agentSettings, .agentHooks] : [.agents]
    case .appearance: isAllProjects ? [.appearance] : []
    case .general: [.general]
    case .hooks: isAllProjects ? [] : [.hooksCreate, .hooksDelete, .hooksEnvironment]
    case .integrations: isAllProjects ? [] : [.integrations]
    case .notifications: isAllProjects ? [.notifications] : []

    case .shortcuts:
      isAllProjects ? [.shortcutsFile, .shortcutsEdit, .shortcutsView, .shortcutsTerminal] : []

    case .terminal: [.terminal]
    case .worktrees: isAllProjects ? [.worktreesNew, .worktreesExisting] : [.worktrees]
    }
  }
}
