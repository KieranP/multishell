import MultishellCore
import SwiftUI

/// A project's glyph as the sidebar, header and picker draw it, tinted from
/// the theme's ANSI slots. A missing project is dimmed, not swapped.
struct ProjectIconView: View {
  let settings: ProjectSettings
  let isMissing: Bool
  let theme: Theme
  let size: Double

  var body: some View {
    glyph
      .frame(width: size + 6, height: size + 6)
      .opacity(isMissing ? 0.45 : 1)
      .overlay(alignment: .bottomTrailing) {
        if isMissing {
          Image(systemName: "questionmark.circle.fill")
            .font(.system(size: max(7, size * 0.6), weight: .bold))
            .foregroundStyle(theme.textSecondary, theme.sidebarColor)
            .offset(x: 3, y: 2)
        }
      }
  }

  @ViewBuilder
  private var glyph: some View {
    Image(systemName: ProjectIcon.kind(of: settings.iconGlyph).symbolName)
      .font(.system(size: size))
      .foregroundStyle(tint)
  }

  private var tint: Color {
    settings.iconTint.map { theme.ansiRGB[$0].color } ?? theme.textSecondary
  }
}
