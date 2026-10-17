import MultishellCore
import SwiftUI

/// One part of the window's colours from its `ui` section, each read only when
/// asked for: a view reads one or two of the six.
struct AreaPalette {
  private let theme: Theme
  /// A key it does not list reads as its base theme's, which has none, so a
  /// view must read only what its section lists.
  private let section: InterfaceSection

  var background: Color { color(.background) }
  var text: Color { color(.text) }
  var textSecondary: Color { color(.textSecondary) }
  var textTertiary: Color { color(.textTertiary) }
  var border: Color { color(.border) }
  var fill: Color { color(.fill) }

  init(_ theme: Theme, _ section: InterfaceSection) {
    self.theme = theme
    self.section = section
  }

  private func color(_ key: InterfaceColorKey) -> Color {
    theme.color(key, in: section)
  }
}
