import MultishellAppCore
import MultishellCore
import SwiftUI

/// A tile's name, legend and the shown slot's value, beside or over its chart.
/// Its width is the tile's to set; a caption longer than it wraps.
struct DebugTileLabel: View {
  let metric: DebugMetric
  let slot: DebugTimelineSlot?
  let theme: Theme
  let metrics: UIMetrics

  var body: some View {
    VStack(alignment: .leading, spacing: 1) {
      Text(metric.title)
        .font(metrics.font(size: metrics.caption))
        .foregroundStyle(theme.debugInfo.textSecondary)
        .lineLimit(1)
      if !metric.series.isEmpty {
        DebugSeriesLegend(series: metric.series, theme: theme, metrics: metrics)
      }
      Text(metric.valueText(of: slot))
        .font(metrics.font(size: metrics.debugTileValueSize, weight: .semibold))
        .monospacedDigit()
        .foregroundStyle(valueColor)
        .lineLimit(1)
      if let detail = slot.flatMap(metric.detailText(of:)) {
        Text(detail)
          .font(metrics.font(size: metrics.small))
          .monospacedDigit()
          .foregroundStyle(theme.debugInfo.textTertiary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var valueColor: Color {
    metric.valueTone(of: slot).map { theme.color(for: $0) }
      ?? theme.debugInfo.text
  }
}
