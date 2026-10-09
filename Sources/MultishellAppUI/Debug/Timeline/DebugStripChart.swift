import MultishellAppCore
import MultishellCore
import SwiftUI

/// One metric across the range, a shape per colour: a `Canvas` drew the
/// whole panel through Metal, 105 MB of buffers (debug-tools.md).
struct DebugStripChart: View, @MainActor Equatable {
  let metric: DebugMetric
  let timeline: DebugTimeline
  let theme: Theme

  var body: some View {
    let points = timeline.points(of: metric)
    ZStack {
      DebugStripLayer(kind: .stalls(timeline.slots.map { $0?.smoothness == .stalled }))
        .fill(theme.failureColor.opacity(0.18))
      DebugStripLayer(kind: .midline).fill(theme.hairline)
      if metric.drawsBars {
        DebugStripLayer(kind: .bars(points)).fill(theme.debugAppSeriesColor)
      } else if metric.isSplitByOwner {
        DebugStripLayer(kind: .band(points, lower: .baseline, upper: .app))
          .fill(theme.debugAppSeriesColor.opacity(0.85))
        DebugStripLayer(kind: .band(points, lower: .app, upper: .appWithTerminals))
          .fill(theme.debugTerminalsSeriesColor)
        DebugStripLayer(kind: .band(points, lower: .appWithTerminals, upper: .total))
          .fill(theme.debugChildrenSeriesColor.opacity(0.85))
      } else {
        DebugStripLayer(kind: .band(points, lower: .baseline, upper: .total))
          .fill(theme.debugAppSeriesColor.opacity(0.15))
        DebugStripLayer(kind: .totalLine(points)).stroke(theme.debugAppSeriesColor, lineWidth: 1.5)
      }
    }
  }

  /// Every field, so a hover, which changes none, leaves the chart undrawn.
  static func == (a: Self, b: Self) -> Bool {
    a.metric == b.metric && a.timeline == b.timeline && a.theme == b.theme
  }
}
