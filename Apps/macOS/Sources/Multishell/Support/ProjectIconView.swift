import MultishellCore
import SwiftUI

/// A project's glyph as the sidebar, the header and the project picker draw
/// it: the folder, or a symbol from the curated list, tinted from the
/// theme's ANSI slots where a tint is set. A missing project is dimmed
/// and badged rather than swapped for another symbol, so the user's choice
/// survives an unmounted drive.
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
    switch ProjectIcon.kind(of: settings.iconGlyph) {
    case .folder:
      Image(systemName: "folder").font(.system(size: size)).foregroundStyle(tint)
    case .symbol(let name):
      Image(systemName: name).font(.system(size: size)).foregroundStyle(tint)
    }
  }

  private var tint: Color {
    settings.iconTint.map { theme.ansiRGB[$0].color } ?? theme.textSecondary
  }
}
