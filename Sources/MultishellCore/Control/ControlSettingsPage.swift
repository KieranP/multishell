/// A settings page or part `--page` turns to on `ui show settings` or
/// `project-settings`, by its command-line word; held to the scope shown.
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
