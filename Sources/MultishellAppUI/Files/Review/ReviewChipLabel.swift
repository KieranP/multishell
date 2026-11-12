import MultishellAppCore
import MultishellCore
import SwiftUI

/// A comment's state as a tinted capsule: pending in the waiting blue, stale
/// lines in the working amber, sent in the area's grey.
struct ReviewChipLabel: View {
  private static var tintOpacity: Double { 0.18 }

  let chip: ReviewChip
  let palette: AreaPalette
  let theme: Theme
  let metrics: UIMetrics

  private var tint: Color {
    switch chip.tone {
    case .stale: theme.color(for: .running, on: palette)
    case .toSend: theme.color(for: .attention, on: palette)
    case .sent: palette.textTertiary
    }
  }

  var body: some View {
    Text(chip.title)
      .font(metrics.font(size: metrics.badge, weight: .semibold))
      .foregroundStyle(tint)
      .lineLimit(1)
      .padding(.horizontal, 6)
      .padding(.vertical, 1)
      .background(tint.opacity(Self.tintOpacity), in: Capsule())
  }
}
