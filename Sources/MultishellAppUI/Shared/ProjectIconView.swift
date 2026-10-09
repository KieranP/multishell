import MultishellAppCore
import MultishellCore
import SwiftUI

/// A project's glyph as the sidebar and header draw it, tinted from
/// the theme's ANSI slots. A missing project is dimmed, not swapped.
struct ProjectIconView: View {
  let settings: ProjectSettings
  let isMissing: Bool
  /// What the missing badge's disc is filled with: what the icon sits on, as
  /// `PaneGlyph`'s ring is.
  let ringFill: Color
  let theme: Theme
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
            .foregroundStyle(theme.textSecondary, ringFill)
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
    theme.iconTint(settings.iconTint, untinted: theme.textSecondary)
  }
}
