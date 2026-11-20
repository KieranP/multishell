/// One point of a tile's chart as fractions of its height: where each series'
/// band tops out, bottom to top, the last the whole.
public struct DebugChartPoint: Sendable, Equatable {
  let tops: [Double]

  public var total: Double { tops.last ?? 0 }
}
