import Foundation

/// What the app's and a project's settings windows share.
enum SettingsWindowSize {
  /// Fixed, or the window would resize as the user moved between tabs. 600
  /// is the tallest page plus slack; SettingsWindowSizeTests holds it.
  static let fixed = CGSize(width: 560, height: 600)
}
