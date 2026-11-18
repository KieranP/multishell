import MultishellAppCore
import MultishellCore
import SwiftUI

/// Every metric as a tile, most telling first, two to a row where they fit; one
/// pointer runs across them all, so a stall lines up with what ran beside it.
struct DebugTimelineView: View {
  let timeline: DebugTimeline
  let theme: Theme
  let metrics: UIMetrics

  @State private var hoveredSlotIndex: Int?
  @State private var width = 0.0

  var body: some View {
    let layout = DebugTileGridLayout.of(
      width: width,
      labelWidth: metrics.debugTileLabelWidth,
      minimumChartWidth: metrics.debugTileMinimumChartWidth,
      tilePadding: UIMetrics.debugTilePadding,
      gap: UIMetrics.debugTileGap,
    )
    Grid(horizontalSpacing: UIMetrics.debugTileGap, verticalSpacing: UIMetrics.debugTileGap) {
      ForEach(rows(of: layout.columnCount), id: \.self) { row in
        GridRow {
          ForEach(row, id: \.self) { metric in
            DebugTileView(
              metric: metric,
              timeline: timeline,
              chartBesideLabel: layout.chartsBesideLabels,
              hoveredSlotIndex: $hoveredSlotIndex,
              theme: theme,
              metrics: metrics,
            )
          }
        }
      }
    }
    .frame(maxWidth: .infinity)
    .onGeometryChange(for: Double.self) { geometry in
      geometry.size.width
    } action: { newWidth in
      width = newWidth
    }
    .onChange(of: timeline.range) { hoveredSlotIndex = nil }
  }

  private func rows(of columnCount: Int) -> [[DebugMetric]] {
    stride(from: 0, to: DebugMetric.allCases.count, by: columnCount).map { start in
      Array(DebugMetric.allCases[start..<min(start + columnCount, DebugMetric.allCases.count)])
    }
  }
}
