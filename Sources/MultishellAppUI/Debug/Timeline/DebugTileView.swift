import MultishellAppCore
import MultishellCore
import SwiftUI

/// One tile: its label beside or over its chart, reading the latest slot
/// unless the pointer is over one in any tile.
struct DebugTileView: View {
  let metric: DebugMetric
  let timeline: DebugTimeline
  let showsChartBesideLabel: Bool
  @Binding var hoveredSlotIndex: Int?
  let theme: Theme
  let metrics: UIMetrics

  @State private var chartWidth = 0.0

  var body: some View {
    let slot = timeline.shownSlot(hovering: hoveredSlotIndex)
    let label = DebugTileLabel(metric: metric, slot: slot, theme: theme, metrics: metrics)
    Group {
      if showsChartBesideLabel {
        HStack(alignment: .top, spacing: UIMetrics.debugTileGap) {
          label.frame(width: metrics.debugTileLabelWidth, alignment: .leading)
          chartColumn
        }
      } else {
        VStack(alignment: .leading, spacing: UIMetrics.debugTileGap) {
          label
          chartColumn
        }
      }
    }
    .padding(UIMetrics.debugTilePadding)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .columnBackground(theme.color(.blockBackground, in: .debugInfo))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(metric.title)
    .accessibilityValue(
      [metric.valueText(of: slot), slot.flatMap(metric.detailText(of:))]
        .compactMap(\.self).joined(separator: ", ")
    )
  }

  private var chartColumn: some View {
    VStack(spacing: 2) {
      DebugTileChart(metric: metric, timeline: timeline, theme: theme)
        .equatable()
        .overlay {
          DebugChartPointer(
            slotIndex: hoveredSlotIndex,
            timeline: timeline,
            color: theme.debugInfo.textSecondary,
          )
        }
        .frame(height: metrics.debugTileChartHeight)
        .onGeometryChange(for: Double.self) { geometry in
          geometry.size.width
        } action: { newWidth in
          chartWidth = newWidth
        }
        .onContinuousHover { phase in
          guard case .active(let location) = phase else {
            hoveredSlotIndex = nil
            return
          }
          hoveredSlotIndex = timeline.slotIndex(atX: location.x, chartWidth: chartWidth)
        }
      axis
    }
    .frame(maxWidth: .infinity)
  }

  private var axis: some View {
    HStack {
      Text(timeline.range.agoTitle)
      Spacer()
      if let slot = timeline.slot(at: hoveredSlotIndex) {
        Text(slot.startedAtText).foregroundStyle(theme.debugInfo.textSecondary)
        Spacer()
      }
      Text(t("debug.axis-now"))
    }
    .font(metrics.font(size: metrics.small))
    .monospacedDigit()
    .foregroundStyle(theme.debugInfo.textTertiary)
  }
}
