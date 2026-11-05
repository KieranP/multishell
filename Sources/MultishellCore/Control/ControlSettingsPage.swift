/// A settings page or part `ui show settings --page` turns to, by the word the
/// command line spells it with; the app holds it to the scope shown.
public enum ControlSettingsPage: String, Codable, CaseIterable, Sendable {
  case agentHooks = "agent-hooks"
  /// A project's Agents page, and All Projects' first Agents part.
  case agents
  case agentSettings = "agent-settings"
  case appearance
  case general
  case hooksCreate = "hooks-create"
  case hooksDelete = "hooks-delete"
  case hooksEnvironment = "hooks-environment"
  case integrations
  case notifications
  case terminal
  case worktrees
}
