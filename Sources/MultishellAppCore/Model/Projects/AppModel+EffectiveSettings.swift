import MultishellCore

extension AppModel {
  /// The project's own, the repository's not layered in. By id: a write from
  /// a settings form's captured copy would undo anything changed meanwhile.
  public func ownSettings(of project: Project) -> ProjectSettings {
    workspace.project(project.id)?.settings ?? project.settings
  }

  /// The project's settings with its repository's file filling the gaps, and
  /// what every path, hook and icon decision reads.
  public func effectiveSettings(for project: Project) -> ProjectSettings {
    project.settings.layered(over: project.sharedSettings.confined)
  }

  /// The project as the git layer should see it, hooks and overrides
  /// resolved.
  func withEffectiveSettings(_ project: Project) -> Project {
    var resolved = project
    resolved.settings = effectiveSettings(for: project)
    return resolved
  }

  /// A worktree's project with the repository's file layered in: reading
  /// `project.settings` would pass over what the file says.
  func resolvedProject(of worktree: Worktree) -> Project? {
    workspace.project(worktree.projectID).map(withEffectiveSettings)
  }

  /// Where this project's worktrees go and how their branches are named,
  /// after the repository's defaults and the user's overrides.
  public func worktreeSettings(for project: Project) -> WorktreeSettings {
    effectiveSettings(for: project).effectiveWorktreeSettings(defaults: workspace.worktreeDefaults)
  }

  /// The value in force where this project does not override, and where it
  /// came from. What the settings forms show and seed an override with.
  public func inherited<Value: Equatable & Sendable>(
    _ setting: InheritableSetting<Value>, global: Value, for project: Project
  ) -> InheritedSetting<Value> {
    if let shared = sharedSettingsInForce(for: project)?[keyPath: setting.shared] {
      return InheritedSetting(value: shared, isFromRepository: true)
    }
    return InheritedSetting(value: global, isFromRepository: false)
  }

  /// The repository's settings as they apply here, what the yes covers dropped
  /// until it is given. The same view `layered` resolves against.
  private func sharedSettingsInForce(for project: Project) -> SharedProjectSettings? {
    guard let shared = project.sharedSettings.confined else { return nil }
    return trustsSharedSettings(of: project) ? shared : shared.withoutWhatTrustCovers
  }
}
