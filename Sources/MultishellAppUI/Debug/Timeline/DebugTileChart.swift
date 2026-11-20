import MultishellAppCore
import MultishellCore
import SwiftUI

/// One tile's chart across the range, a shape per colour: a `Canvas` drew the
/// whole panel through Metal, 105 MB of buffers (debug-tools.md).
struct DebugTileChart: View, @MainActor Equatable {
  let metric: DebugMetric
  let timeline: DebugTimeline
  let theme: Theme

  var body: some View {
    let points = timeline.points(of: metric)
    ZStack {
      DebugChartLayer(kind: .stalls(timeline.slots.map { $0?.smoothness == .stalled }))
        .fill(theme.debugStallColor.opacity(0.18))
      DebugChartLayer(kind: .midline).fill(theme.debugInfo.border)
      if metric.drawsBars {
        DebugChartLayer(kind: .bars(points)).fill(theme.debugAppSeriesColor)
      } else if !metric.series.isEmpty {
        ForEach(Array(metric.series.enumerated()), id: \.offset) { index, band in
          DebugChartLayer(
            kind: .band(
              points,
              lower: index == 0 ? .baseline : .top(ofSeries: index - 1),
              upper: .top(ofSeries: index),
            )
          )
          .fill(theme.color(for: band).opacity(0.85))
        }
      } else {
        DebugChartLayer(kind: .band(points, lower: .baseline, upper: .total))
          .fill(theme.debugAppSeriesColor.opacity(0.15))
        DebugChartLayer(kind: .totalLine(points)).stroke(theme.debugAppSeriesColor, lineWidth: 1.5)
      }
    }
  }

  /// Every field, so a hover, which changes none, leaves the chart undrawn.
  static func == (a: Self, b: Self) -> Bool {
    a.metric == b.metric && a.timeline == b.timeline && a.theme == b.theme
  }
}
