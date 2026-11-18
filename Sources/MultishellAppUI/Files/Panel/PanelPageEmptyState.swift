import MultishellAppCore
import MultishellCore
import SwiftUI

/// A page with nothing to show, Review, a services' page or the All changes
/// tab: why, and what would change that.
struct PanelPageEmptyState<Glyph: Shape, Action: View>: View {
  let text: PanelPageEmptyText
  /// The area the page sits in: the Files panel's, or a file tab's.
  let palette: AreaPalette
  let metrics: UIMetrics
  /// Drawn large and thin in the page's faintest grey.
  let glyph: Glyph
  @ViewBuilder let action: () -> Action

  var body: some View {
    VStack(spacing: 10) {
      glyph
        .stroke(
          style: StrokeStyle(
            lineWidth: metrics.emptyPageGlyphLineWidth,
            lineCap: .round,
            lineJoin: .round,
          )
        )
        .frame(width: metrics.emptyPageGlyphSide, height: metrics.emptyPageGlyphSide)
        .foregroundStyle(palette.textTertiary)
        .accessibilityHidden(true)
      Text(text.title)
        .font(metrics.font(size: metrics.bodySize, weight: .semibold))
        .foregroundStyle(palette.text)
      if let detail = text.detail {
        Text(detail)
          .font(metrics.font(size: metrics.caption))
          .foregroundStyle(palette.textSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      action()
        .controlSize(.small)
        .padding(.top, 4)
    }
    .multilineTextAlignment(.center)
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
