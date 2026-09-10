import MultishellCore
import SwiftUI

extension RGB {
  var color: Color {
    Color(.sRGB, red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255)
  }
}

/// Every chrome colour derives from the theme, so the window follows the
/// theme rather than the system appearance and a light terminal gets a light
/// sidebar.
extension Theme {
  var backgroundColor: Color { backgroundRGB.color }
  var foregroundColor: Color { foregroundRGB.color }

  /// Sidebar sits furthest from the terminal, toolbar and tab strip between.
  var sidebarColor: Color { lifted(0.09) }
  var chromeColor: Color { lifted(0.045) }

  /// A board column, and a card on it: two more steps away from the
  /// terminal, drawn from the same lift the sidebar and toolbar are so a
  /// light theme gets a light board.
  var columnColor: Color { lifted(0.03) }
  var cardColor: Color { lifted(0.07) }

  var textPrimary: Color { foregroundColor.opacity(0.92) }
  var textSecondary: Color { foregroundColor.opacity(0.6) }
  var textTertiary: Color { foregroundColor.opacity(0.38) }
  var hairline: Color { foregroundColor.opacity(0.09) }
  var rowHover: Color { foregroundColor.opacity(0.06) }

  var colorScheme: ColorScheme { isDark ? .dark : .light }

  /// Working is the theme's yellow, Waiting its blue, Done its green, Failed
  /// its red, and nothing running a grey. The sidebar's dirty-files dot is
  /// the same yellow, so the state dot sits on the left where the icon was,
  /// never beside it.
  func color(for state: SessionState) -> Color {
    switch state {
    case .running: ansiRGB[3].color
    case .attention: ansiRGB[4].color
    case .done: ansiRGB[2].color
    case .error: ansiRGB[1].color
    case .idle: textTertiary
    }
  }

  private func lifted(_ amount: Double) -> Color {
    backgroundRGB.blended(with: isDark ? .white : .black, amount: amount).color
  }
}
