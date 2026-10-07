import MultishellAppCore
import MultishellCore
import SwiftUI

/// One strip: its label beside the chart, reading the latest slot unless the
/// pointer is over one.
struct DebugStripView: View {
  let metric: DebugMetric
  let timeline: DebugTimeline
  let hoveredSlotIndex: Int?
  let theme: Theme
  let metrics: UIMetrics

  var body: some View {
    let label = DebugStripLabel(
      metric: metric, slot: timeline.slot(at: hoveredSlotIndex) ?? timeline.latestSlot,
      theme: theme, metrics: metrics)
    HStack(spacing: 0) {
      label.frame(width: metrics.debugStripLabelWidth, alignment: .leading)
      DebugStripCanvas(metric: metric, timeline: timeline, theme: theme)
        .equatable()
        .overlay {
          DebugStripPointer(
            slotIndex: hoveredSlotIndex, timeline: timeline, color: theme.textSecondary)
        }
        .padding(.vertical, 5)
        .padding(.trailing, UIMetrics.debugChartTrailingInset)
    }
    .frame(height: metrics.debugStripHeight)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(metric.title)
    .accessibilityValue(metric.valueText(of: label.slot))
  }
}
