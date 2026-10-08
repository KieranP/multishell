import MultishellCore

extension AppModel {
  /// The project's own, the repository's not layered in. By id: a write from
  /// a settings form's captured copy would undo anything changed meanwhile.
  public func ownSettings(of project: Project) -> ProjectSettings {
    currentCopy(of: project).settings
  }

  public func setSettings(_ settings: ProjectSettings, for project: Project) {
    store.setSettings(settings, forProject: project.id)
  }

  /// The project's settings with its repository's file filling the gaps, and
  /// what every path, hook and icon decision reads.
  public func effectiveSettings(for project: Project) -> ProjectSettings {
    project.settings.layered(over: project.sharedSettingsSnapshot.confined)
  }

  /// The project as the git layer should see it, its settings the effective
  /// ones: the repository's file filling the gaps the user's own leave.
  func effectiveProject(_ project: Project) -> Project {
    var effective = project
    effective.settings = effectiveSettings(for: project)
    return effective
  }

  /// A worktree's project with the repository's file layered in: reading
  /// `project.settings` would pass over what the file says.
  func effectiveProject(of worktree: Worktree) -> Project? {
    workspace.project(worktree.projectID).map(effectiveProject)
  }

  /// Where this project's worktrees go and how their branches are named,
  /// after the repository's defaults and the user's overrides.
  func effectiveWorktreeSettings(for project: Project) -> WorktreeSettings {
    workspace.effectiveWorktreeSettings(for: effectiveProject(project))
  }

  /// The value in force where this project does not override, and where it
  /// came from. What the settings forms show and seed an override with.
  public func inherited<Value: Equatable & Sendable>(
    _ setting: InheritableSettingKeys<Value>, global: Value, for project: Project
  ) -> InheritedSetting<Value> {
    if let shared = sharedSettingsInForce(for: project)?[keyPath: setting.shared] {
      return InheritedSetting(value: shared, isFromRepository: true)
    }
    return InheritedSetting(value: global, isFromRepository: false)
  }

  private func sharedSettingsInForce(for project: Project) -> SharedProjectSettings? {
    project.sharedSettingsSnapshot.confined.map(project.settings.sharedSettingsInForce)
  }
}
