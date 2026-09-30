import MultishellCore

extension AppModel {
  /// The shell picker's row for the global choice, the login shell where
  /// nothing is stored. What a project inherits and shows while not overriding it.
  public var globalShellID: String {
    workspace.preferredShellID ?? ShellCatalogue.loginShellID
  }
}
