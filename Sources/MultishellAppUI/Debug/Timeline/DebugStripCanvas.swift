import MultishellAppCore
import MultishellCore
import SwiftUI

/// One metric across the range: bars for a count, an area for a level, the
/// app's part under the rest, and a red band through every stalled slot.
struct DebugStripCanvas: View {
  let metric: DebugMetric
  let timeline: DebugTimeline
  let theme: Theme

  var body: some View {
    let points = timeline.points(of: metric)
    Canvas { context, size in
      let slotWidth = size.width / Double(max(points.count, 1))
      drawStalls(in: &context, size: size, slotWidth: slotWidth)
      context.fill(
        Path(CGRect(x: 0, y: size.height / 2, width: size.width, height: 0.5)),
        with: .color(theme.hairline))
      if metric.drawsBars {
        drawBars(points, in: &context, size: size, slotWidth: slotWidth)
      } else {
        drawAreas(points, in: &context, size: size, slotWidth: slotWidth)
      }
    }
  }

  private func drawStalls(in context: inout GraphicsContext, size: CGSize, slotWidth: Double) {
    for (index, slot) in timeline.slots.enumerated() where slot?.smoothness == .stalled {
      context.fill(
        Path(
          CGRect(x: Double(index) * slotWidth, y: 0, width: max(slotWidth, 2), height: size.height)),
        with: .color(theme.failureColor.opacity(0.18)))
    }
  }

  private func drawBars(
    _ points: [DebugStripPoint?], in context: inout GraphicsContext, size: CGSize,
    slotWidth: Double
  ) {
    let barWidth = max(slotWidth - 1, 1)
    for (index, point) in points.enumerated() {
      guard let point, point.total > 0 else { continue }
      let height = max(point.total * size.height, 1)
      context.fill(
        Path(
          roundedRect: CGRect(
            x: Double(index) * slotWidth, y: size.height - height, width: barWidth, height: height),
          cornerRadius: min(1.5, barWidth / 2)),
        with: .color(theme.debugAppSeriesColor))
    }
  }

  private func drawAreas(
    _ points: [DebugStripPoint?], in context: inout GraphicsContext, size: CGSize,
    slotWidth: Double
  ) {
    for segment in DebugStripSegment.segments(in: points) {
      let positions = segment.slotPositions.map { (x: $0.slot * slotWidth, point: $0.point) }
      let y = { (fraction: Double) in size.height - fraction * size.height }
      if metric.isSplitByOwner {
        context.fill(
          band(positions, lower: { _ in y(0) }, upper: { y($0.app) }),
          with: .color(theme.debugAppSeriesColor.opacity(0.85)))
        context.fill(
          band(positions, lower: { y($0.app) }, upper: { y($0.appWithTerminals) }),
          with: .color(theme.debugTerminalsSeriesColor))
        context.fill(
          band(positions, lower: { y($0.appWithTerminals) }, upper: { y($0.total) }),
          with: .color(theme.debugChildrenSeriesColor.opacity(0.85)))
      } else {
        context.fill(
          band(positions, lower: { _ in y(0) }, upper: { y($0.total) }),
          with: .color(theme.debugAppSeriesColor.opacity(0.15)))
        var line = Path()
        line.addLines(positions.map { CGPoint(x: $0.x, y: y($0.point.total)) })
        context.stroke(line, with: .color(theme.debugAppSeriesColor), lineWidth: 1.5)
      }
    }
  }

  /// The area between two edges along a segment, closed back along the lower one.
  private func band(
    _ positions: [(x: Double, point: DebugStripPoint)],
    lower: (DebugStripPoint) -> Double, upper: (DebugStripPoint) -> Double
  ) -> Path {
    var path = Path()
    path.addLines(
      positions.map { CGPoint(x: $0.x, y: upper($0.point)) }
        + positions.reversed().map { CGPoint(x: $0.x, y: lower($0.point)) })
    path.closeSubpath()
    return path
  }
}

/// Every field, so a hover, which changes none, leaves the chart undrawn.
extension DebugStripCanvas: @MainActor Equatable {
  static func == (a: DebugStripCanvas, b: DebugStripCanvas) -> Bool {
    a.metric == b.metric && a.timeline == b.timeline && a.theme == b.theme
  }
}
