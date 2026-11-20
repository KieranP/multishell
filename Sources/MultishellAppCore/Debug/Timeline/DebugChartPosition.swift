/// A point placed across a chart `height` points tall, its fractions measured up from the bottom.
public struct DebugChartPosition {
  public let x: Double
  let point: DebugChartPoint
  let height: Double

  public init(x: Double, point: DebugChartPoint, height: Double) {
    self.x = x
    self.point = point
    self.height = height
  }

  public func y(_ boundary: DebugChartBoundary) -> Double {
    height - boundary.fraction(of: point) * height
  }
}
