import MultishellCore
import SwiftUI

/// Every chrome colour is the theme's, so the window follows it rather than
/// the system appearance; see Docs/design/appearance.md.
extension Theme {
  /// How far a sidebar row's name is held back until the row is selected.
  private static let unselectedRowNameOpacity = 0.85

  var projectsPanel: AreaPalette { AreaPalette(self, .projectsPanel) }
  var filesPanel: AreaPalette { AreaPalette(self, .filesPanel) }
  var header: AreaPalette { AreaPalette(self, .header) }
  var tabBar: AreaPalette { AreaPalette(self, .tabBar) }
  /// The shown terminal tab's face, and the dividers between its panes.
  var terminalTab: AreaPalette { AreaPalette(self, .terminalTab) }
  /// The shown file tab's face, its bar and its notices.
  var fileTab: AreaPalette { AreaPalette(self, .fileTab) }
  var findBar: AreaPalette { AreaPalette(self, .findBar) }
  var agentsPanel: AreaPalette { AreaPalette(self, .agentsPanel) }
  var agentsColumn: AreaPalette { AreaPalette(self, .agentsColumn) }
  var agentsCard: AreaPalette { AreaPalette(self, .agentsCard) }
  var detail: AreaPalette { AreaPalette(self, .detail) }
  var debugInfo: AreaPalette { AreaPalette(self, .debugInfo) }

  var colorScheme: ColorScheme { isDark ? .dark : .light }

  /// A pane's own background, which the fade dims every other pane towards;
  /// opaque, as libghostty draws it.
  var terminalBackground: Color { (terminalRGB(.background) ?? .black).opaque.color }

  /// The git badge's lines added and removed, and its files with no line.
  var insertionsColor: Color { color(.added, in: .git) }
  var deletionsColor: Color { color(.removed, in: .git) }
  var unscoredFilesColor: Color { color(.changed, in: .git) }

  /// A create or remove that failed, and a branch that landed.
  var failureColor: Color { color(.failed, in: .states) }
  var mergedColor: Color { color(.merged, in: .git) }

  func color(_ key: InterfaceColorKey, in section: InterfaceSection) -> Color {
    interfaceRGB(key, in: section).color
  }

  func rowNameColor(isSelected: Bool) -> Color {
    projectsPanel.text.opacity(isSelected ? 1 : Self.unselectedRowNameOpacity)
  }

  func iconTint(_ slot: Int?, untinted: Color) -> Color {
    slot.map { projectIconRGB($0).color } ?? untinted
  }

  /// Idle is the grey of the area the dot sits in.
  func color(for state: SessionState, on palette: AreaPalette) -> Color {
    switch state {
    case .running: color(.working, in: .states)
    case .attention: color(.waiting, in: .states)
    case .done: color(.done, in: .states)
    case .failed: color(.failed, in: .states)
    case .idle: palette.textTertiary
    }
  }
}
