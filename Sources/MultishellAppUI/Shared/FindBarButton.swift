import MultishellCore
import SwiftUI

/// One glyph of the bar, lit on hover so the three read as buttons rather
/// than marks.
struct FindBarButton: View {
  let symbol: String
  let help: String
  let theme: Theme
  let metrics: UIMetrics
  let action: () -> Void
  @State private var isHovered = false

  var body: some View {
    PlainGlyphButton(help: help, action: action) {
      Image(systemName: symbol)
        .font(metrics.font(size: metrics.bodySize, weight: .medium))
        .frame(width: metrics.findControlSize, height: metrics.findControlSize)
        .glyphHover(isHovered, palette: theme.findBar, resting: theme.findBar.textSecondary)
        .accessibilityHidden(true)
    }
    .tracksHover($isHovered)
  }
}
