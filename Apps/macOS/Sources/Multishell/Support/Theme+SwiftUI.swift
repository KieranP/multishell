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

  var textPrimary: Color { foregroundColor.opacity(0.92) }
  var textSecondary: Color { foregroundColor.opacity(0.6) }
  var textTertiary: Color { foregroundColor.opacity(0.38) }
  var hairline: Color { foregroundColor.opacity(0.09) }
  var rowHover: Color { foregroundColor.opacity(0.06) }

  var colorScheme: ColorScheme { isDark ? .dark : .light }

  private func lifted(_ amount: Double) -> Color {
    backgroundRGB.blended(with: isDark ? .white : .black, amount: amount).color
  }
}
