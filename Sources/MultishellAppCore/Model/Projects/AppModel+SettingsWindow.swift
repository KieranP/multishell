import MultishellCore

extension AppModel {
  /// The project the settings window shows: the one asked for, else the
  /// selected one, the Window menu opening it with none asked for.
  public var settingsWindowProjectID: Project.ID? {
    requestedSettingsProjectID ?? selectedProject?.id
  }
}
