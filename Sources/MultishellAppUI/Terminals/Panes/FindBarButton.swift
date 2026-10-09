import MultishellCore
import SwiftUI

/// One glyph of the bar, lit on hover so the three read as buttons rather
/// than marks.
struct FindBarButton: View {
  let symbol: String
  let label: String
  let theme: Theme
  let metrics: UIMetrics
  let action: () -> Void
  @State private var isHovered = false

  var body: some View {
    PlainGlyphButton(help: label, action: action) {
      Image(systemName: symbol)
        .font(.system(size: metrics.bodySize, weight: .medium))
        .foregroundStyle(isHovered ? theme.textPrimary : theme.textSecondary)
        .frame(width: metrics.findControlSize, height: metrics.findControlSize)
        .background(isHovered ? theme.faintFill : .clear, in: RoundedRectangle(cornerRadius: 6))
        .accessibilityHidden(true)
    }
    .onHover { isHovered = $0 }
  }
}
