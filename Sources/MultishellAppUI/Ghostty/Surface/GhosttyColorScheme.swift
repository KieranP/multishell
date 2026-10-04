import AppKit
import GhosttyKit

/// What a pane tells a program asking whether the terminal is light or dark.
/// The view's appearance follows the app's theme, not the system's.
enum GhosttyColorScheme {
  static func scheme(for appearance: NSAppearance) -> ghostty_color_scheme_e {
    scheme(isDark: appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua)
  }

  static func scheme(isDark: Bool) -> ghostty_color_scheme_e {
    isDark ? GHOSTTY_COLOR_SCHEME_DARK : GHOSTTY_COLOR_SCHEME_LIGHT
  }
}
