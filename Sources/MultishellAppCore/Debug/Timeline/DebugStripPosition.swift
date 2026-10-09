/// A point placed across a strip `height` points tall, its fractions measured up from the bottom.
public struct DebugStripPosition {
  public let x: Double
  let point: DebugStripPoint
  let height: Double

  public init(x: Double, point: DebugStripPoint, height: Double) {
    self.x = x
    self.point = point
    self.height = height
  }

  public func y(_ boundary: DebugStripBoundary) -> Double {
    height - boundary.fraction(of: point) * height
  }
}
