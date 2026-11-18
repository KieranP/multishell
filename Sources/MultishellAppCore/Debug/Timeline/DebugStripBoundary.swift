/// An edge a tile's band is drawn between, read off a point.
public enum DebugStripBoundary: Sendable {
  case baseline
  /// Where the series at this index, counted from the bottom, tops out.
  case top(ofSeries: Int)
  /// The top of the stack.
  case total

  func fraction(of point: DebugStripPoint) -> Double {
    switch self {
    case .baseline: 0
    case .top(let index): point.tops.indices.contains(index) ? point.tops[index] : point.total
    case .total: point.total
    }
  }
}
