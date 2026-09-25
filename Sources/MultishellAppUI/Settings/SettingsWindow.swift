import Foundation

/// What the app's and a project's settings windows share.
enum SettingsWindow {
  /// Fixed, or the window would resize as the user moved between tabs. 600
  /// is the tallest page plus slack; AppSettingsWindowTests holds it.
  static let size = CGSize(width: 560, height: 600)
}
