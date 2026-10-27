import MultishellAppCore

extension AppModel {
  /// Whether the menu item of this title can act now, for the quick switcher.
  /// The menu keeps each on, as a disabled item gives its key to the pane.
  func isMenuCommandAvailable(titled title: String) -> Bool {
    MenuCommandAvailability.byTitle[title].map { self[keyPath: $0] } ?? true
  }
}
