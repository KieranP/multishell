import MultishellCore

extension AppModel {
  /// The project the settings window shows: the one asked for, else the
  /// selected one, the Window menu opening it with none asked for.
  public var settingsWindowProjectID: Project.ID? {
    requestedSettingsProjectID ?? settingsWindowFallbackProject?.id
  }

  /// What the project settings window shows when opened with no project
  /// named: the selected worktree's project, or the only project.
  var settingsWindowFallbackProject: Project? { project(of: workspace.selectedWorktree) }
}
