import MultishellAppCore
import MultishellCore
import SwiftUI

/// Every metric on one time axis, one pointer across them all, so a stall
/// lines up with whatever ran in the same second.
struct DebugTimelineView: View {
  let timeline: DebugTimeline
  let theme: Theme
  let metrics: UIMetrics

  @State private var hoveredSlotIndex: Int?
  /// The charts' width, the strips' less their labels, to place the pointer.
  @State private var chartWidth = 0.0

  var body: some View {
    VStack(spacing: 0) {
      ForEach(DebugMetric.allCases, id: \.self) { metric in
        DebugStripView(
          metric: metric, timeline: timeline, hoveredSlotIndex: hoveredSlotIndex, theme: theme,
          metrics: metrics
        )
        .hairline(.bottom, theme)
      }
      axis
    }
    .padding(.vertical, 6)
    .background(theme.columnColor, in: RoundedRectangle(cornerRadius: UIMetrics.columnCornerRadius))
    .onContinuousHover { phase in
      hoveredSlotIndex = slotIndex(under: phase)
    }
    .onChange(of: timeline.range) { hoveredSlotIndex = nil }
  }

  private var axis: some View {
    HStack(spacing: 0) {
      Color.clear.frame(width: metrics.debugStripLabelWidth, height: 1)
      HStack {
        Text(timeline.range.agoTitle)
        Spacer()
        if let slot = timeline.slot(at: hoveredSlotIndex) {
          Text(slot.startedAt.formatted(date: .omitted, time: .standard))
            .foregroundStyle(theme.textSecondary)
          Spacer()
        }
        Text(t("debug.axis-now"))
      }
      .onGeometryChange(for: Double.self) {
        $0.size.width
      } action: {
        chartWidth = $0
      }
      .padding(.trailing, UIMetrics.debugChartTrailingInset)
    }
    .font(.system(size: metrics.small))
    .monospacedDigit()
    .foregroundStyle(theme.textTertiary)
    .padding(.top, 4)
  }

  /// The slot under the pointer, `nil` over the labels or off the strips.
  private func slotIndex(under phase: HoverPhase) -> Int? {
    guard case .active(let location) = phase, chartWidth > 0 else { return nil }
    let x = location.x - metrics.debugStripLabelWidth
    guard x >= 0, x <= chartWidth else { return nil }
    return timeline.slotIndex(atFraction: x / chartWidth)
  }
}
