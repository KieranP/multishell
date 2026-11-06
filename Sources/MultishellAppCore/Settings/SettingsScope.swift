import MultishellCore

/// Whose settings the settings window shows: those every project follows, or
/// one project's own overrides of them.
public enum SettingsScope: Hashable, Sendable {
  case allProjects
  case project(Project.ID)
}
