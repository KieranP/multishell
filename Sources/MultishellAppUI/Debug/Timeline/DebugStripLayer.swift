import MultishellAppCore
import SwiftUI

/// One colour's part of a strip, every slot's piece in a single path.
struct DebugStripLayer: Shape {
  enum Kind: Sendable {
    case stalls([Bool])
    case midline
    case bars([DebugStripPoint?])
    case band([DebugStripPoint?], lower: DebugStripBoundary, upper: DebugStripBoundary)
    case totalLine([DebugStripPoint?])
  }

  let kind: Kind

  func path(in rect: CGRect) -> Path {
    switch kind {
    case .stalls(let flags): stalls(flags, in: rect.size)
    case .midline: Path(CGRect(x: 0, y: rect.height / 2, width: rect.width, height: 0.5))
    case .bars(let points): bars(points, in: rect.size)

    case .band(let points, let lower, let upper):
      joinedSegments(points, in: rect.size) { band($0, lower: lower, upper: upper) }

    case .totalLine(let points):
      joinedSegments(points, in: rect.size) { positions in
        var path = Path()
        path.addLines(positions.map { CGPoint(x: $0.x, y: $0.y(.total)) })
        return path
      }
    }
  }

  private func stalls(_ flags: [Bool], in size: CGSize) -> Path {
    let slotWidth = size.width / Double(max(flags.count, 1))
    var path = Path()
    for (index, isStalled) in flags.enumerated() where isStalled {
      path.addRect(
        CGRect(x: Double(index) * slotWidth, y: 0, width: max(slotWidth, 2), height: size.height)
      )
    }
    return path
  }

  private func bars(_ points: [DebugStripPoint?], in size: CGSize) -> Path {
    let slotWidth = size.width / Double(max(points.count, 1))
    let barWidth = max(slotWidth - 1, 1)
    let corner = min(1.5, barWidth / 2)
    var path = Path()
    for (index, point) in points.enumerated() {
      guard let point, point.total > 0 else { continue }
      let height = max(point.total * size.height, 1)
      path.addRoundedRect(
        in: CGRect(
          x: Double(index) * slotWidth,
          y: size.height - height,
          width: barWidth,
          height: height,
        ),
        cornerSize: CGSize(width: corner, height: corner),
      )
    }
    return path
  }

  private func joinedSegments(
    _ points: [DebugStripPoint?],
    in size: CGSize,
    piece: ([DebugStripPosition]) -> Path,
  ) -> Path {
    let slotWidth = size.width / Double(max(points.count, 1))
    var path = Path()
    for segment in DebugStripSegment.segments(in: points) {
      path.addPath(
        piece(
          segment.slotPositions.map { slot, point in
            DebugStripPosition(x: slot * slotWidth, point: point, height: size.height)
          }
        )
      )
    }
    return path
  }

  /// Closed back along the lower boundary.
  private func band(
    _ positions: [DebugStripPosition],
    lower: DebugStripBoundary,
    upper: DebugStripBoundary,
  ) -> Path {
    var path = Path()
    path.addLines(
      positions.map { CGPoint(x: $0.x, y: $0.y(upper)) }
        + positions.reversed().map { CGPoint(x: $0.x, y: $0.y(lower)) }
    )
    path.closeSubpath()
    return path
  }
}
