/// Consecutive points of a strip with a reading in each, so an area is drawn
/// in pieces rather than bridged across slots no sample landed in.
public struct DebugStripSegment: Sendable, Equatable {
  let firstIndex: Int
  let points: [DebugStripPoint]

  /// Where each point is drawn, in slots from the strip's left edge. A lone
  /// point spans its slot, a line through one point drawing nothing.
  public var slotPositions: [(slot: Double, point: DebugStripPoint)] {
    if points.count == 1, let point = points.first {
      return [(Double(firstIndex), point), (Double(firstIndex + 1), point)]
    }
    return points.enumerated().map { (Double(firstIndex + $0.offset) + 0.5, $0.element) }
  }

  public static func segments(in points: [DebugStripPoint?]) -> [Self] {
    var segments: [Self] = []
    var start = 0
    var current: [DebugStripPoint] = []
    for (index, point) in points.enumerated() {
      if let point {
        if current.isEmpty { start = index }
        current.append(point)
      } else if !current.isEmpty {
        segments.append(Self(firstIndex: start, points: current))
        current = []
      }
    }
    if !current.isEmpty { segments.append(Self(firstIndex: start, points: current)) }
    return segments
  }
}
