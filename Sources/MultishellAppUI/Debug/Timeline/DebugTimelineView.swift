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
  /// The charts' width, the strips' less their labels, to find the slot under
  /// the pointer.
  @State private var chartWidth = 0.0

  var body: some View {
    VStack(spacing: 0) {
      ForEach(DebugMetric.allCases, id: \.self) { metric in
        DebugStripView(
          metric: metric,
          timeline: timeline,
          hoveredSlotIndex: hoveredSlotIndex,
          theme: theme,
          metrics: metrics,
        )
        .hairline(.bottom, theme.debugInfo)
      }
      axis
    }
    .padding(.vertical, 6)
    .columnBackground(theme.color(.blockBackground, in: .debugInfo))
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
          Text(slot.startedAtText)
            .foregroundStyle(theme.debugInfo.textSecondary)
          Spacer()
        }
        Text(t("debug.axis-now"))
      }
      .onGeometryChange(for: Double.self) { geometry in
        geometry.size.width
      } action: { newWidth in
        chartWidth = newWidth
      }
      .padding(.trailing, UIMetrics.debugChartTrailingInset)
    }
    .font(metrics.font(size: metrics.small))
    .monospacedDigit()
    .foregroundStyle(theme.debugInfo.textTertiary)
    .padding(.top, 4)
  }

  /// The slot under the pointer, `nil` over the labels or off the strips.
  private func slotIndex(under phase: HoverPhase) -> Int? {
    guard case .active(let location) = phase else { return nil }
    return timeline.slotIndex(
      atX: location.x,
      labelWidth: metrics.debugStripLabelWidth,
      chartWidth: chartWidth,
    )
  }
}
