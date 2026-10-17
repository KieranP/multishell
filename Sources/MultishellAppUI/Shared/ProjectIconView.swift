import MultishellAppCore
import MultishellCore
import SwiftUI

/// A project's glyph as the sidebar and header draw it, tinted from the
/// theme's `ui.project_icons`. A missing project is dimmed, not swapped.
struct ProjectIconView: View {
  let settings: ProjectSettings
  let isMissing: Bool
  let theme: Theme
  /// What the icon sits on, whose background fills the missing badge's disc
  /// as `PaneGlyph`'s ring is filled.
  let palette: AreaPalette
  let size: Double

  var body: some View {
    glyph
      .frame(
        width: UIMetrics.projectIconSlot(forGlyphOf: size),
        height: UIMetrics.projectIconSlot(forGlyphOf: size),
      )
      .opacity(isMissing ? 0.45 : 1)
      .overlay(alignment: .bottomTrailing) {
        if isMissing {
          Image(systemName: "questionmark.circle.fill")
            .font(.system(size: UIMetrics.cornerBadgeSize(onGlyphOf: size), weight: .bold))
            .foregroundStyle(palette.textSecondary, palette.background)
            .offset(x: 3, y: 2)
            .accessibilityHidden(true)
        }
      }
  }

  @ViewBuilder
  private var glyph: some View {
    Image(systemName: settings.iconKind.symbolName)
      .font(.system(size: size))
      .foregroundStyle(tint)
      .accessibilityHidden(true)
  }

  private var tint: Color {
    theme.iconTint(settings.iconTint, untinted: palette.textSecondary)
  }
}
