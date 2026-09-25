import MultishellCore
import SwiftUI

/// Every chrome colour derives from the theme, so the window follows it
/// rather than the system appearance; see Docs/design/appearance.md.
extension Theme {
  var backgroundColor: Color { backgroundRGB.color }
  var foregroundColor: Color { foregroundRGB.color }

  /// Sidebar sits furthest from the terminal, toolbar and tab strip between.
  var sidebarColor: Color { lifted(0.09) }
  var chromeColor: Color { lifted(0.045) }

  /// A board column and a card on it: two more steps from the terminal,
  /// drawn from the same lift the sidebar and toolbar are.
  var columnColor: Color { lifted(0.03) }
  var cardColor: Color { lifted(0.07) }

  /// The find bar: the sidebar's lift on a dark theme, a third of it on a
  /// light one, whose well then needs a line of its own; see appearance.md.
  var findPanelColor: Color { isDark ? sidebarColor : columnColor }
  var findWellBorderColor: Color { isDark ? .clear : hairline }

  var textPrimary: Color { foregroundColor.opacity(0.92) }
  var textSecondary: Color { foregroundColor.opacity(0.6) }
  var textTertiary: Color { foregroundColor.opacity(0.38) }
  var hairline: Color { foregroundColor.opacity(0.09) }
  var rowHover: Color { foregroundColor.opacity(0.06) }

  var colorScheme: ColorScheme { isDark ? .dark : .light }

  /// A worktree's name beside its project's, on the header and a card.
  var worktreeNameColor: Color { ansiRGB(6).color }

  /// The git badge's lines added and removed, and its files with no line.
  var insertionsColor: Color { ansiRGB(2).color }
  var deletionsColor: Color { ansiRGB(1).color }
  var unscoredFilesColor: Color { ansiRGB(3).color }

  /// A create or remove that failed, and a branch that landed.
  var failureColor: Color { ansiRGB(1).color }
  var mergedColor: Color { ansiRGB(2).color }

  /// A project icon's tint slot, or `untinted` for an icon without one.
  func iconTint(_ slot: Int?, untinted: Color) -> Color {
    slot.map { ansiRGB($0).color } ?? untinted
  }

  /// Working yellow, Waiting blue, Done green, Failed red, idle grey. The
  /// dirty-files dot is the same yellow, so the two never sit together.
  func color(for state: SessionState) -> Color {
    switch state {
    case .running: ansiRGB(3).color
    case .attention: ansiRGB(4).color
    case .done: ansiRGB(2).color
    case .failed: ansiRGB(1).color
    case .idle: textTertiary
    }
  }

  private func lifted(_ amount: Double) -> Color {
    backgroundRGB.blended(with: isDark ? .white : .black, amount: amount).color
  }
}
