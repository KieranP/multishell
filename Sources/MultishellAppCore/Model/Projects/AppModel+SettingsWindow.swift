import MultishellCore

extension AppModel {
  /// A project's own menu asking for its settings, which the window opened
  /// after this shows.
  public func requestSettings(for project: Project) {
    requestedSettingsProjectID = project.id
  }

  /// The project the settings window shows: the one asked for, else the
  /// selected one, the Window menu opening it with none asked for.
  public var settingsWindowProjectID: Project.ID? {
    requestedSettingsProjectID ?? settingsWindowFallbackProject?.id
  }

  /// What the project settings window shows when opened with no project
  /// named: the selected worktree's project, or the only project.
  var settingsWindowFallbackProject: Project? {
    projectOrOnlyProject(of: workspace.selectedWorktree)
  }
}
