import MultishellAppCore
import MultishellCore
import SwiftUI

/// A strip's name, legend and the shown slot's value, the column beside its
/// chart. Its width is the strip's to set; see `UIMetrics.debugStripLabelWidth`.
struct DebugStripLabel: View {
  let metric: DebugMetric
  let slot: DebugTimelineSlot?
  let theme: Theme
  let metrics: UIMetrics

  var body: some View {
    VStack(alignment: .leading, spacing: 1) {
      HStack(spacing: 6) {
        Text(metric.title)
          .font(.system(size: metrics.caption))
          .foregroundStyle(theme.textSecondary)
        if metric.isSplitByOwner {
          DebugSeriesLegend(metric: metric, theme: theme, metrics: metrics)
        }
      }
      Text(metric.valueText(of: slot))
        .font(.system(size: metrics.debugStripValueSize, weight: .semibold))
        .monospacedDigit()
        .foregroundStyle(valueColor)
      if let detail = slot.flatMap(metric.detailText(of:)) {
        Text(detail)
          .font(.system(size: metrics.small))
          .monospacedDigit()
          .foregroundStyle(theme.textTertiary)
      }
    }
    .lineLimit(1)
    .padding(.horizontal, Self.horizontalPadding)
  }

  private static let horizontalPadding = 12.0

  private var valueColor: Color {
    metric.valueSmoothness(of: slot).map(theme.smoothnessColor) ?? theme.textPrimary
  }
}
