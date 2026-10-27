import MultishellAppCore
import MultishellCore
import SwiftUI

/// A services' page with nothing to show: why, and what would change that.
struct PanelEmptyState<Glyph: Shape, Action: View>: View {
  let text: PanelEmptyText
  let theme: Theme
  let metrics: UIMetrics
  /// Drawn large and thin in the page's faintest grey.
  let glyph: Glyph
  @ViewBuilder let action: () -> Action

  var body: some View {
    let glyphSide = metrics.bodySize * 2
    VStack(spacing: 10) {
      glyph
        .stroke(
          style: StrokeStyle(lineWidth: glyphSide * 1.1 / 16, lineCap: .round, lineJoin: .round)
        )
        .frame(width: glyphSide, height: glyphSide)
        .foregroundStyle(theme.filesPanel.textTertiary)
        .accessibilityHidden(true)
      Text(text.title)
        .font(metrics.font(size: metrics.bodySize, weight: .semibold))
        .foregroundStyle(theme.filesPanel.text)
      if let detail = text.detail {
        Text(detail)
          .font(metrics.font(size: metrics.caption))
          .foregroundStyle(theme.filesPanel.textSecondary)
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
