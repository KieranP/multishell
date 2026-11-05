/// What the settings window's detail shows: a page, or one part of a page
/// split because it would not fit the window (Docs/design/settings.md).
public enum SettingsSection: Hashable, Sendable {
  case agentHooks
  /// A project's agent overrides, its whole Agents page.
  case agents
  /// The preferred agent and Auto Rename, the first part of All Projects' Agents.
  case agentSettings
  case appearance
  case general
  case hooksCreate
  case hooksDelete
  case hooksEnvironment
  case integrations
  case notifications
  case terminal
  case worktrees

  /// One of a split page's parts, listed under its page in the sidebar.
  public var isPart: Bool {
    switch self {
    case .agentHooks, .agentSettings, .hooksCreate, .hooksDelete, .hooksEnvironment: true
    case .agents, .appearance, .general, .integrations, .notifications, .terminal, .worktrees: false
    }
  }

  public var page: SettingsPage {
    switch self {
    case .agentHooks, .agents, .agentSettings: .agents
    case .appearance: .appearance
    case .general: .general
    case .hooksCreate, .hooksDelete, .hooksEnvironment: .hooks
    case .integrations: .integrations
    case .notifications: .notifications
    case .terminal: .terminal
    case .worktrees: .worktrees
    }
  }
}
