import Foundation

/// Drawing eight full windows holds the main actor the UI suites share, so `make
/// theme-audit` runs MonochromeThemeTests and `make test` leaves them out.
enum ThemeAudit {
  static let isRequested = ProcessInfo.processInfo.environment["MULTISHELL_THEME_AUDIT"] == "1"
}
