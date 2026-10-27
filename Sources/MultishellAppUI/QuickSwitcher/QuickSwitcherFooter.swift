import MultishellAppCore
import MultishellCore
import SwiftUI

/// The keys the panel answers to, in the faintest text.
struct QuickSwitcherFooter: View {
  let palette: AreaPalette
  let metrics: UIMetrics

  var body: some View {
    HStack(spacing: 14) {
      Text(t("quick-switcher.hint.move"))
      Text(t("quick-switcher.hint.open"))
      Text(t("quick-switcher.hint.scope"))
      Spacer(minLength: 0)
      Text(t("quick-switcher.hint.close"))
    }
    .font(metrics.font(size: metrics.badge))
    .foregroundStyle(palette.textTertiary)
    .lineLimit(1)
    .padding(.horizontal, UIMetrics.quickSwitcherSideInset)
    .frame(height: metrics.paneRowHeight)
    .accessibilityElement(children: .combine)
  }
}
